import (
	"vela/ql"
)

parameter: {
	name:       string
	namespace?: string
	cluster?:   string
	kind:       string
	apiVersion: string
}
response: ql.#Read & {
	value: {
		apiVersion: parameter.apiVersion
		kind:       parameter.kind
		metadata: {
			name: parameter.name
			if parameter.namespace != _|_ {
				namespace: parameter.namespace
			}
		}
	}
	if parameter.cluster != _|_ {
		cluster: parameter.cluster
	}
}

if response.err == _|_ {
	status: {
		resource: response.value
	}
}
if response.err != _|_ {
	status: {
		error: response.err
	}
}
