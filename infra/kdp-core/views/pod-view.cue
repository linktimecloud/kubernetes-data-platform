import (
	"vela/ql"
	"list"
)

parameter: {
	name:      string
	namespace: string
	cluster:   *"" | string
}

pod: ql.#Read & {
	value: {
		apiVersion: "v1"
		kind:       "Pod"
		metadata: {
			name:      parameter.name
			namespace: parameter.namespace
		}
	}
	cluster: parameter.cluster
}

eventList: ql.#SearchEvents & {
	value: {
		apiVersion: "v1"
		kind:       "Pod"
		metadata:   pod.value.metadata
	}
	cluster: parameter.cluster
}

podMetrics: ql.#Read & {
	cluster: parameter.cluster
	value: {
		apiVersion: "metrics.k8s.io/v1beta1"
		kind:       "PodMetrics"
		metadata: {
			name:      parameter.name
			namespace: parameter.namespace
		}
	}
}

status: {
	if pod.err == _|_ {
		workload: {
			apiVersion: pod.value.metadata.ownerReferences[0].apiVersion
			kind:       pod.value.metadata.ownerReferences[0].kind
			name:       pod.value.metadata.ownerReferences[0].name
			namespace:  pod.value.metadata.namespace
		}
		if pod.value.status.phase != "Pending" && pod.value.status.phase != "Unknown" {
			if pod.value.spec.nodeName != _|_ {
				node: pod.value.spec.nodeName
			}
		}
		if pod.value.spec.affinity != _|_ {
			affinity: pod.value.spec.affinity
		}
		apiVersion: pod.value.apiVersion
		kind:       pod.value.kind
		metadata: {
			name:         pod.value.metadata.name
			namespace:    pod.value.metadata.namespace
			if pod.value.metadata.labels != _|_ {
				labels:       pod.value.metadata.labels
			}
			if pod.value.metadata.annotations != _|_ {
				annotations:  pod.value.metadata.annotations
			}
			creationTime: pod.value.metadata.creationTimestamp
		}

		status: pod.value.status
		if pod.value.status.containerStatuses != _|_ {
			_containerRestartCount: [ for container in pod.value.status.containerStatuses {
				container.restartCount
			}]
			restartCount: list.Sum(_containerRestartCount)
		}

		containers: [ for container in pod.value.spec.containers {
			name:  container.name
			image: container.image
			resources: {
				if container.resources.limits != _|_ {
					limits: container.resources.limits
				}
				if container.resources.requests != _|_ {
					requests: container.resources.requests
				}
				if podMetrics.err == _|_ {
					usage: {for containerUsage in podMetrics.value.containers {
						if containerUsage.name == container.name {
							cpu:    containerUsage.usage.cpu
							memory: containerUsage.usage.memory
						}
					}}
				}
			}
			if pod.value.status.containerStatuses != _|_ {
				status: {for containerStatus in pod.value.status.containerStatuses if containerStatus.name == container.name {
					state:        containerStatus.state
					restartCount: containerStatus.restartCount
					ready:        containerStatus.ready
				}}
			}
		}]
		if eventList.err == _|_ {
			events: eventList.list
		}
	}
	if pod.err != _|_ {
		error: pod.err
	}
}
