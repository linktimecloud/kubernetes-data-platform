import (
	"vela/ql"
	"list"
)

parameter: {
	appName:    string
	appNs:      string
	name?:      string
	cluster?:   string
	clusterNs?: string
}

result: ql.#CollectPods & {
	app: {
		name:      parameter.appName
		namespace: parameter.appNs
		filter: {
			if parameter.cluster != _|_ {
				cluster: parameter.cluster
			}
			if parameter.clusterNs != _|_ {
				clusterNamespace: parameter.clusterNs
			}
			if parameter.name != _|_ {
				components: [parameter.name]
			}
		}
	}
}

if result.err == _|_ {
	status: {
		podList: [ for pod in result.list if pod.object != _|_ {
			cluster:    pod.cluster
			workload:   pod.workload
			component:  pod.component
			apiVersion: pod.object.apiVersion
			kind:       pod.object.kind
			// object: pod
			metadata: {
				name:         pod.object.metadata.name
				namespace:    pod.object.metadata.namespace
				creationTime: pod.object.metadata.creationTimestamp
				if pod.object.metadata.labels != _|_ {
					labels:       pod.object.metadata.labels
				}
				version: {
					if pod.publishVersion != _|_ {
						publishVersion: pod.publishVersion
					}
					if pod.deployVersion != _|_ {
						deployVersion: pod.deployVersion
					}
				}
			}
			status: pod.object.status
			// refer to https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-phase
			if pod.object.status.phase != "Pending" && pod.object.status.phase != "Unknown" {
				if pod.object.spec.nodeName != _|_ {
					nodeName: pod.object.spec.nodeName
				}
			}
			if pod.object.status.containerStatuses != _|_ {
				_containerRestartCount: [ for container in pod.object.status.containerStatuses {
					container.restartCount
				}]
				restartCount: list.Sum(_containerRestartCount)
			}
		}]
	}
}

if result.err != _|_ {
	status: {
		error: result.err
	}
}
