"ctx-setting-hive-server2": {
    description: "Init hive server2 context setting resource"
    type:        "xdefinition"
    attributes: {
        apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "ContextSetting"
				type:       "hive-server2"
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
            "zookeeper_node": parameter.zkNode
        }
    }
    parameter: {
        hiveSite: string
        host: string
        port: string
        url: string
        zkNode: string
    }
}