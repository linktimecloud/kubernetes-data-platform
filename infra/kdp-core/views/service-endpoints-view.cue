import (
	"vela/ql"
)

parameter: {
	appName:    string
	appNs:      string
	name?:      string
	cluster?:   string
	clusterNs?: string
}
resources: ql.#CollectServiceEndpoints & {
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
if resources.err == _|_ {
	status: {
		endpoints: resources.list
	}
}
if resources.err != _|_ {
	status: {
		error: resources.err
	}
}
