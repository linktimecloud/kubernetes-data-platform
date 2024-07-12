#!/usr/bin/env python3

import filecmp
import json
import os
import difflib
import shutil
import subprocess
import traceback

import sys
from deepdiff import DeepDiff
from functools import reduce
from jsonpath import jsonpath

from kubernetes import client, config


BASE_DIR = os.environ["HOME"] + "/.kdp"
OPERATOR_LOG_FILE = f"{BASE_DIR}/operator.log"
INFRA_PROJECT_DIR = f"{BASE_DIR}/src/infra"
HOOK_RESULT_FILE = os.environ.get("BINDING_CONTEXT_PATH")

LABELS_TERMINATED = "installer.kdp.io/terminated"
ANNOTATIONS_LAST_COMMAND = "installer.kdp.io/last-command"
ANNOTATIONS_LAST_SPEC = "installer.kdp.io/spec-data"

RETRY_NUM = 0
MAX_RETRY_NUM = 10
MAX_INSTALL_NUM = 3

#
RunningWorkflow = "runningWorkflow"

WorkflowFailed = "workflowFailed"
# Component insufficiency
Insufficiency = "insufficiency"
# All components are in the correct status
Running = "running"
# The component is complete, but the status is incorrect
Unhealthy = "unhealthy"
# Too many runs still failed
Terminated = "terminated"


ADDON_NAMES = ["addon-fluxcd", "addon-openebs", "addon-plg-stack", "addon-kong", "addon-mysql", "addon-kdp-core"]
STEPS = []

config.load_incluster_config()
api_instance = client.CustomObjectsApi()


def get_items(obj, items, default=None):
    """递归获取数据
    """
    if isinstance(items, str):
        items = items.strip(".").split(".")
    try:
        return reduce(lambda x, i: x[i], items, obj)
    except (IndexError, KeyError, TypeError):
        return default


def transform_data(data):
    transformed_list = []
    if data:
        for item in data:
            name = item["name"]
            value = item["value"]
            transformed_list.append(f"--set {name}={value}")
    return transformed_list


def execute_cmd(command, save_file=True):
    try:
        output = subprocess.check_output(command, shell=True, stderr=subprocess.STDOUT)
        if save_file:
            with open(OPERATOR_LOG_FILE, 'w') as f:
                f.write(output.decode("utf-8"))
        return output.decode("utf-8")
    except subprocess.CalledProcessError as e:
        print(e)
        raise
    except Exception as e:
        print(e)
        raise


def deal_operator_message():
    with open(OPERATOR_LOG_FILE, 'r') as f:
        lines = f.readlines()
        line_data = lines[-10:]
        operator_log_data = ''.join(line_data)
    message_data = operator_log_data.replace('"', '\"')
    message_data = message_data.replace("[\x1b[36m", '')
    message_data = message_data.replace("\x1b[0m]", '')
    return message_data


def get_set_parameters(context_data):
    kdp_repo = get_items(context_data, ["object", "spec", "kdpRepo"])
    kdp_repo_ref = get_items(context_data, ["object", "spec", "kdpRepoRef"])
    docker_registry = get_items(context_data, ["object", "spec", "dockerRegistry"])
    helm_repository = get_items(context_data, ["object", "spec", "helmRepository"])
    force_reinstall = get_items(context_data, ["object", "spec", "forceReinstall"])
    artifact_server = get_items(context_data, ["object", "spec", "artifactServer"])
    spec_parameters = get_items(context_data, ["object", "spec", "setParameters"])
    set_cmd = ""
    if kdp_repo != "nil":
        set_cmd = f"{set_cmd} --kdp-repo {kdp_repo}"

    if kdp_repo_ref != "nil":
        set_cmd = f"{set_cmd} --kdp-repo-ref {kdp_repo_ref}"

    if force_reinstall:
        set_cmd = f"{set_cmd} --force-reinstall"

    if artifact_server != "nil":
        set_cmd = f"{set_cmd} --artifact-server {artifact_server}"

    if docker_registry != "nil":
        set_cmd = f"{set_cmd} --set docker-registry={docker_registry}"

    if helm_repository != "nil":
        set_cmd = f"{set_cmd} --set helm-repository={helm_repository}"

    set_parameters = " ".join(transform_data(spec_parameters))
    if set_parameters:
        set_cmd = f"{set_cmd} {set_parameters}"

    return set_cmd


def check_infra_spec_data(context_data):
    last_spec_data = get_items(context_data, ["object", "metadata", "annotations", ANNOTATIONS_LAST_SPEC])
    current_spec_data = get_items(context_data, ["object", "spec"])
    file_cmp_result = DeepDiff(json.loads(last_spec_data), current_spec_data, ignore_order=True)
    if not file_cmp_result:
        print(f"infra spec not change, not operator")
        return True
    return False


def check_infra_step_status():
    steps = []
    status = Running
    for addon_name in ADDON_NAMES:
        try:
            addon_application = VelaApplication(addon_name).get_application()
        except Exception as e:
            print(e)
            steps.append({
                "name": addon_name,
                "status": "",
                "message": "",
                "lastExecuteTime": ""
            })
            status = Insufficiency
            continue
        addon_status = jsonpath(addon_application, '$.status.status')
        message = jsonpath(addon_application, '$.status.services[*].message')
        last_execute_time = jsonpath(addon_application, '$.status.workflow.endTime')
        steps.append({
            "name": addon_name,
            "status": addon_status[0] if addon_status else "",
            "message": message[0] if message else "",
            "lastExecuteTime": last_execute_time[0] if last_execute_time else ""
        })
        if addon_status[0] != "running":
            status = Unhealthy
            continue
    return status, steps


class KubernetesCrdController(object):
    def __init__(self):
        self.api_instance = api_instance


class VelaApplication(KubernetesCrdController):
    def __init__(self, name):
        super().__init__()
        self.group = "core.oam.dev"
        self.version = "v1beta1"
        self.plural = "applications"
        self.nameSpace = "vela-system"
        self.name = name

    def get_application(self):
        try:
            return self.api_instance.get_namespaced_custom_object(
                self.group, self.version, self.nameSpace, self.plural, self.name)
        except Exception as e:
            print(e)
            raise


class InfraKubernetes(KubernetesCrdController):
    def __init__(self, name):
        super().__init__()
        self.group = "installer.kdp.io"
        self.version = "v1alpha1"
        self.plural = "infrastructures"
        self.name = name

    def get_infra_status(self):
        try:
            infra_data = self.api_instance.get_cluster_custom_object(
                self.group, self.version, self.plural, self.name)
            return get_items(infra_data, ["status", "status"])
        except Exception as e:
            print(e)
            raise

    def path_status(self, status=None, message=None, steps=None):
        body_status = {}
        if status:
            body_status["status"] = status
        if message:
            body_status["message"] = message
        if steps:
            body_status["subSteps"] = steps
        body = {
            "status": body_status
        }
        api_instance.patch_cluster_custom_object_status(
            self.group, self.version, self.plural, self.name, body)
        print("patch infra status success")

    def path_annotations_command(self, command):
        try:
            infra_data = self.api_instance.get_cluster_custom_object(
                self.group, self.version, self.plural, self.name)
            infra_data["metadata"]["annotations"] = {
                ANNOTATIONS_LAST_COMMAND: command
            }
            self.api_instance.patch_cluster_custom_object(
                self.group, self.version, self.plural, self.name, infra_data)
        except Exception as e:
            print(e)
            raise

    def path_label_terminated(self):
        try:
            infra_data = self.api_instance.get_cluster_custom_object(
                self.group, self.version, self.plural, self.name)
            infra_data["metadata"]["labels"] = {
                LABELS_TERMINATED: "infra"
            }
            self.api_instance.patch_cluster_custom_object(self.group, self.version, self.plural, self.name, infra_data)
        except Exception as e:
            print(e)
            raise

    def path_annotations_last_spec(self, spec_data):
        try:
            infra_data = self.api_instance.get_cluster_custom_object(
                self.group, self.version, self.plural, self.name)
            infra_data["metadata"]["annotations"] = {
                ANNOTATIONS_LAST_SPEC: json.dumps(spec_data)
            }
            self.api_instance.patch_cluster_custom_object(
                self.group, self.version, self.plural, self.name, infra_data)
        except Exception as e:
            print(traceback.format_exc())
            print(e)
            raise


class InfraController(InfraKubernetes):
    def __init__(self, name, infra_spec):
        super().__init__(name)
        self.name = name
        self.infra_spec = infra_spec

    def pre_infra_operator(self):
        self.path_status(RunningWorkflow, "", [])
        if os.path.exists(OPERATOR_LOG_FILE):
            os.remove(OPERATOR_LOG_FILE)

    def create_infra(self, set_cmd):
        self.pre_infra_operator()
        # Store the spec data
        self.path_annotations_last_spec(self.infra_spec)
        create_cmd = f"kdp install {set_cmd}"
        try:
            self.handle_infra("create", create_cmd)
        except Exception as e:
            print(e)

    def upgrade_infra(self, set_cmd):
        self.pre_infra_operator()
        upgrade_cmd = f"kdp upgrade {set_cmd}"
        try:
            self.handle_infra("upgrade", upgrade_cmd)
            # Store the spec data after the update is successful
            self.path_annotations_last_spec(self.infra_spec)
        except Exception as e:
            print(traceback.format_exc())
            print(e)

    def schedule_infra(self, schedule_cmd):
        try:
            self.handle_infra("schedule", schedule_cmd)
        except Exception as e:
            print(e)

    def handle_infra(self, handle_type, handle_cmd):
        global RETRY_NUM
        try:
            self.path_annotations_command(handle_cmd)
            if RETRY_NUM > MAX_RETRY_NUM:
                self.path_label_terminated()

            print(f"{handle_type} {self.name} with command: {handle_cmd}")
            _ = execute_cmd(handle_cmd)
            message_data = deal_operator_message()
            status, steps = check_infra_step_status()
            self.path_status(status, message_data, steps)
            if handle_type == "schedule":
                if status == Running:
                    RETRY_NUM = 0
                if status != Running:
                    RETRY_NUM += 1
        except Exception as e:
            self.path_status(status=WorkflowFailed, message=str(e))
            if handle_type == "schedule":
                RETRY_NUM += 1
            raise


def check_labels(context_data):
    labels = get_items(context_data, ["object", "metadata", "labels"])
    if labels:
        for label in labels:
            if label == LABELS_TERMINATED:
                return True
    return False


def get_last_command(context_data):
    return get_items(context_data, ["object", "metadata", "annotations", ANNOTATIONS_LAST_COMMAND])


def get_last_spec(context_data):
    return get_items(context_data, ["object", "metadata", "annotations", ANNOTATIONS_LAST_SPEC])


def infra_operator():
    hook_result_file = os.environ.get("BINDING_CONTEXT_PATH")
    shutil.copy(hook_result_file, "/tmp/modify.json")
    with open(hook_result_file, 'r') as hook_file:
        context_file_data = hook_file.read()
    json_data = json.loads(context_file_data)

    for context_data in json_data:
        object_type = get_items(context_data, ["type"])
        if object_type == "Event":
            object_watch_type = get_items(context_data, ["watchEvent"])
            object_name = get_items(context_data, ["object", "metadata", "name"])
            object_kind = get_items(context_data, ["object", "kind"])
            object_spec = get_items(context_data, ["object", "spec"])
            set_cmd = get_set_parameters(context_data)

            shutil.copy(HOOK_RESULT_FILE, "/tmp/Event.json")

            # check labels
            if check_labels(context_data):
                print(f"{object_kind}/{object_name} labels is terminated, disallowed operation")
                continue

            if object_watch_type == "Added":
                InfraController(object_name, object_spec).create_infra(set_cmd)
            if object_watch_type == "Modified":

                # check spec data change or not
                if check_infra_spec_data(context_data):
                    continue
                InfraController(object_name, object_spec).upgrade_infra(set_cmd)
            if object_watch_type == "Deleted":
                print(f"{object_kind}/{object_name} delete, not support operator")
                continue
        if object_type == "Schedule":
            shutil.copy(HOOK_RESULT_FILE, "/tmp/Schedule.json")
            schedule_infra = get_items(context_data, ["snapshots", "infra-labels"])
            for infra_line in schedule_infra:
                object_name = get_items(infra_line, ["object", "metadata", "name"])
                object_kind = get_items(infra_line, ["object", "kind"])
                object_status = get_items(infra_line, ["object", "status", "status"])
                object_spec = get_items(infra_line, ["object", "spec"])
                set_cmd = get_set_parameters(infra_line)

                if not object_spec:
                    print(f"{object_kind}/{object_name} spec is empty, not support operator")
                    continue

                if check_labels(infra_line):
                    print(f"{object_kind}/{object_name} labels is terminated, disallowed operation")
                    continue

                # object_status = InfraKubernetes(object_name).get_infra_status()
                if object_status == RunningWorkflow:
                    continue

                if object_status == WorkflowFailed:
                    command = get_last_command(infra_line)
                    InfraController(object_name, object_spec).schedule_infra(command)

                if object_status == Insufficiency or object_status == Unhealthy:
                    command = f"kdp install {set_cmd}"
                    if RETRY_NUM > MAX_INSTALL_NUM:
                        command = f"kdp install --force-reinstall {set_cmd}"
                    InfraController(object_name, object_spec).schedule_infra(command)

                command = f"kdp install {set_cmd}"
                InfraController(object_name, object_spec).schedule_infra(command)
        if object_type == "Synchronization":
            print("synchronization, not support operator")
            shutil.copy(HOOK_RESULT_FILE, "/tmp/Synchronization.json")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--config":
        print("""configVersion: v1
schedule:
  - name: 'schedule-infra'
    crontab: '*/4 * * * *'
    allowFailure: true
    queue: 'schedule-queue'
    includeSnapshotsFrom: ['infra-labels']
kubernetes:
  - name: 'infra-labels'
    apiVersion: 'installer.kdp.io/v1alpha1'
    kind: 'Infrastructure'
    allowFailure: true
    jqFilter: '.metadata.labels'
  - name: 'infra-spec'
    apiVersion: 'installer.kdp.io/v1alpha1'
    kind: 'Infrastructure'
    allowFailure: true
    jqFilter: '.spec'""")
    else:
        infra_operator()
