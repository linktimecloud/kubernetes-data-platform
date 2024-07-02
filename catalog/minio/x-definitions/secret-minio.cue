"ctx-secret-minio": {
	description: ""
	type:        "xdefinition"
	attributes: {
		apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "ContextSecret"
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
		kind:       "Secret"
		metadata: {
			name:        context.name
			namespace:   context.namespace
			annotations: context.bdcAnnotations
		}
		type: "Opaque"
		data: {
			"MINIO_ROOT_USER":     parameter.MINIO_ROOT_USER
			"MINIO_ROOT_PASSWORD": parameter.MINIO_ROOT_PASSWORD
		}
	}
	parameter: {
		// +ui:description=MinIO root user
		MINIO_ROOT_USER: string

		// +ui:description=MinIO root user password
		MINIO_ROOT_PASSWORD: string
	}
}
