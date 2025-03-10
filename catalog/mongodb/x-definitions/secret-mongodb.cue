"ctx-secret-mongodb": {
	description: ""
	type:        "xdefinition"
	attributes: {
		apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "ContextSecret"
				type:       "mongodb"
			}
		}
	}
	labels: {}
	annotations: {}
}

template: {
	output: {
		apiVersion: "v1"
		kind:       "Secret"
		metadata: {
			name:        context.name
			namespace:   context.namespace
			annotations: context.bdcAnnotations
		}
		type: "Opaque"
		data: {
			"MONGODB_ROOT_USER":     parameter.MONGODB_ROOT_USER
			"MONGODB_ROOT_PASSWORD": parameter.MONGODB_ROOT_PASSWORD
		}
	}
	parameter: {
		// +ui:description=root user
		MONGODB_ROOT_USER: string

		// +ui:description=root user password
		MONGODB_ROOT_PASSWORD: string
	}
}
