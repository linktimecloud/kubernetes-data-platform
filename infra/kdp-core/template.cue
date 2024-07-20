package main

import (
	"encoding/json"
)

_version: {
	kdp: "v1.2.1"
	operator: "v1.1.1"
	catalogManager: "v1.0.0"
	ux: "v1.2.0"
}

_ns: {
	name: parameter.namePrefix + "ns"
	type: "k8s-objects"
	properties: objects: [{
		apiVersion: "v1"
		kind:       "Namespace"
		metadata: name: parameter.namespace
	}]
}

output: {
	apiVersion: "core.oam.dev/v1beta1"
	kind: "Application"
	metadata: name: context.metadata.name
	spec: {
		components: [
			_ns,
			_sharedConfigs,
			_sharedSecrets,
			_velaOps,
			_configReplicator,
			_configReloader,
			_kdpCloudTty,
			_kdpCloudttyIngress,
			_KdpTerminalConfig,
			_kdpTerminalConfigTask,
			_kdpOAMOperator,
			_kdpCatalogManager,
			_kdpUX,
			_bdcDef,
			_systemBDC,
		] + _kdpIngressMiddleware

		policies: [
			{
				type: "shared-resource"
				name: "shared-res"
				properties: rules: [
					{
						selector: resourceTypes: [
							"Namespace",
							"ConfigMap",
							"Secret",
							"XDefinition",
						]
					}
				]
			},
			{
				type: "take-over"
				name: "take-over-res"
				properties: rules: [
					{
						selector: resourceTypes: [
							"Namespace",
							"ConfigMap",
							"Secret",
							"XDefinition",
						]
					}
				]
			},
			{
				type: "garbage-collect"
				name: "gc-excluded-res"
				properties: rules: [
					{
						selector: resourceTypes: [
							"Namespace",
							"ConfigMap",
							"Secret",
							"XDefinition",
						]
						strategy: "never"
					}
				]
			},
			{
				type: "apply-once"
				name: "apply-once-res"
				properties: {
					enable: true
					rules: [
							{
								selector: resourceTypes: [
									"Namespace",
									"Job",
									"CronJob"
								]
								strategy: {
									path: ["*"]
								}
							},
							{
								selector: resourceTypes: [
									"Ingress"
								]
								strategy: {
									affect: "onStateKeep"
									path: ["*"]
								}
							}
						]
				}
			}
		]

		workflow: steps: [
			{
				type: "apply-component"
				name: "apply-ns"
				properties: component: parameter.namePrefix + "ns"
			},
			{
				type: "step-group"
				name: "apply-shared-configurations"
				subSteps: [
					{
						type: "apply-component"
						name: "apply-shared-configs"
						properties: component: parameter.namePrefix + "shared-configs"
					},
					{
						type: "apply-component"
						name: "apply-shared-secrets"
						properties: component: parameter.namePrefix + "shared-secrets"
					}
				]
			},
			{
				type: "step-group"
				name: "apply-workloads"
				subSteps: [
					{
						type: "apply-component"
						name: "apply-vela-ops"
						properties: component: parameter.namePrefix + "vela-ops"
					},
					{
						type: "apply-component"
						name: "apply-config-replicator"
						properties: component: parameter.namePrefix + "config-replicator"
					},
					{
						type: "apply-component"
						name: "apply-config-reloader"
						properties: component: parameter.namePrefix + "config-reloader"
					},
					{
						type: "apply-component"
						name: "apply-kdp-oam-operator"
						properties: component: parameter.namePrefix + "kdp-oam-operator"
					},
					{
						type: "apply-component"
						name: "apply-kdp-catalog-manager"
						properties: component: parameter.namePrefix + "kdp-catalog-manager"
					},
					{
						type: "apply-component"
						name: "apply-kdp-ux"
						properties: component: parameter.namePrefix + "kdp-ux"
					},
					{
						type: "apply-component"
						name: "apply-cloudtty"
						properties: component: parameter.namePrefix + "cloudtty"
					},
				] + _kdpIngressMiddlewareWorkflow + [
					{
						type: "apply-component"
						name: "apply-cloudtty-ingress"
						properties: component: parameter.namePrefix + "cloudtty-ingress"
					},
					{
						type: "apply-component"
						name: "apply-terminal-config"
						properties: component: parameter.namePrefix + "terminal-config"
					},
					{
						type: "apply-component"
						name: "apply-terminal-config-task"
						properties: component: parameter.namePrefix + "terminal-config-task"
					},
				]
			},
			{
				type: "apply-component"
				name: "apply-bdc-xdef"
				dependsOn: ["apply-workloads"]
				properties: component: parameter.namePrefix + "bdc-definition"
			},
			{
				type: "apply-component"
				name: "apply-system-bdc"
				dependsOn: ["apply-bdc-xdef"]
				properties: component: parameter.namePrefix + "system-bdc"
			},
		]
	}
}

outputs: kafkaResourceTree: {
	apiVersion: "v1"
	kind:       "ConfigMap"
	metadata: {
		name:      "kafka-strimzi-podset-relation"
		namespace: "vela-system"
		labels: {
			"rules.oam.dev/resources":       "true"
			"rules.oam.dev/resource-format": "json"
		}
	}
	data: rules: json.Marshal(_kafkarules)
}

_kafka: {
	group: "kafka.strimzi.io"
	kind:  "Kafka"
}

_kafkaConnect: {
	group: "kafka.strimzi.io"
	kind:  "KafkaConnect"
}

_kafkaSchemaRegistry: {
	group: "kafka.strimzi.io"
	kind:  "KafkaSchemaRegistry"
}

_StrimziPodSet: {
	apiVersion: "core.strimzi.io/v1beta2"
	kind:       "StrimziPodSet"
}

_strimziPodSetApiVersion: {
	group: "core.strimzi.io"
	kind:  "StrimziPodSet"
}

_podApiVersion: {
	apiVersion: "v1"
	kind:       "Pod"
}

_statefulSetApiVersion: {
	apiVersion: "apps/v1"
	kind:"StatefulSet"
}


_kafkarules: [{
	parentResourceType: _kafka
	childrenResourceType: [_StrimziPodSet]
}, {
	parentResourceType: _strimziPodSetApiVersion
	childrenResourceType: [_podApiVersion]
}, {
	parentResourceType: _kafkaConnect
	childrenResourceType: [_deployment]
}, {
	parentResourceType: _kafkaSchemaRegistry
	childrenResourceType: [_statefulSetApiVersion]
}
]


outputs: flinkResourceTree: {
	apiVersion: "v1"
	kind:       "ConfigMap"
	metadata: {
		name:      "flink-pod-relation"
		namespace: "vela-system"
		labels: {
			"rules.oam.dev/resources":       "true"
			"rules.oam.dev/resource-format": "json"
		}
	}
	data: rules: json.Marshal(_flinkrules)
}

_flinkDeployment: {
	group: "flink.apache.org"
	kind:  "FlinkDeployment"
}

_deployment: {
	apiVersion: "apps/v1"
	kind:       "Deployment"
}

_flinkrules: [{
	parentResourceType: _flinkDeployment
	childrenResourceType: [_deployment]
}]
