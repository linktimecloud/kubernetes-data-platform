"ctx-setting-connect": {
    description: "Kafka connect context setting"
    type:        "xdefinition"
    attributes: {
        apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "ContextSetting"
				type:       "connect"
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
            "url": parameter.url
            "host": parameter.host
            "port": parameter.port
        }
    }
    parameter: {
        url: string
        host: string
        port: string
    }
}