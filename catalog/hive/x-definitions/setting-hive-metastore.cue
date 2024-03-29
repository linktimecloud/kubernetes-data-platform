"ctx-setting-hive-metastore": {
    description: "Init hive metastore context setting resource"
    type:        "xdefinition"
    attributes: {
        apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "ContextSetting"
				type:       "hive-metastore"
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
            "hive-site.xml": parameter.hiveSite
            "host": parameter.host
            "port": parameter.port
            "url": parameter.url
        }
    }
    parameter: {
        hiveSite: string
        host: string
        port: string
        url: string
    }
}