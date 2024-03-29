import (
	"vela/config"
)

metadata: {
	name:        "helm-repository"
	alias:       "Helm Repository"
	description: "Config information to authenticate helm chart repository"
	sensitive:   false
	scope:       "project"
}

template: {
	output: {
		apiVersion: "v1"
		kind:       "Secret"
		metadata: {
			name:      context.name
			namespace: context.namespace
			labels: {
				"config.oam.dev/catalog":       "velacore-config"
				"config.oam.dev/type":          "helm-repository"
				"config.oam.dev/multi-cluster": "true"
				"config.oam.dev/sub-type":      "helm"
			}
		}
		type: "Opaque"
		stringData: {
			url: parameter.url
			if parameter.username != _|_ {
				username: parameter.username
			}
			if parameter.password != _|_ {
				password: parameter.password
			}

		}
		data: {
			if parameter.caFile != _|_ {
				caFile: parameter.caFile
			}
		}
	}

	validation: config.#HelmRepository & {
		$params: parameter
	}

	parameter: {
		// +usage=The public url of the helm chart repository.
		url: string
		// +usage=The username of basic auth repo.
		username?: string
		// +usage=The password of basic auth repo.
		password?: string
		// +usage=The ca certificate of helm repository. Please encode this data with base64.
		caFile?: string
	}
}
