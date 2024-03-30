"ctx-setting-zookeeper": {
    description: "Zookeeper context setting resource"
    type:        "xdefinition"
    attributes: {
        apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "ContextSetting"
				type:       "zookeeper"
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
            "host": parameter.host
            "hostname": parameter.hostname
            "port": parameter.port
        }
    }
    parameter: {
        host: string
        hostname: string
        port: string
    }
}