"ctx-setting-kafka": {
    description: "Kafka context setting"
    type:        "xdefinition"
    attributes: {
        apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "ContextSetting"
				type:       "kafka"
			}
		}
    }
	labels: {}
    annotations: {}
}

template: {
    output: {
        apiVersion: "v1"
        kind: "ConfigMap"
        metadata: {
            name: context.name
            namespace: context.namespace
            annotations: context.bdcAnnotations
        }
        data: {
            "bootstrap_plain": parameter.bootstrap_plain,
            "security_protocol": parameter.security_protocol
        }
    }
    parameter: {
        bootstrap_plain: string
        security_protocol: string
    }
}