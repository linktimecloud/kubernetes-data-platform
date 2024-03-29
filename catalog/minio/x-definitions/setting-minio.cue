"ctx-setting-minio": {
	description: "Init minio context setting resource"
	type:        "xdefinition"
	attributes: {
		apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "ContextSetting"
				type:       "minio"
			}
		}
	}
	labels: {}
	annotations: {}
}

template: {
	output: {
		apiVersion: "v1"
		kind:       "ConfigMap"
		metadata: {
			name:        context.name
			namespace:   context.namespace
			annotations: context.bdcAnnotations
		}
		data: {
			"host":           parameter.host
			"authSecretName": parameter.authSecretName
		}
	}
	parameter: {
		host:           string
		authSecretName: string
	}
}
