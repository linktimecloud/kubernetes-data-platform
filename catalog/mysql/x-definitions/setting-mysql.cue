"ctx-setting-mysql": {
    description: "Mysql context setting resource"
    type:        "xdefinition"
    attributes: {
        apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "ContextSetting"
				type:       "mysql"
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
            "MYSQL_HOST": parameter.MYSQL_HOST
            "MYSQL_PORT": parameter.MYSQL_PORT
        }
    }
    parameter: {
        // +ui:description=mysql的地址
        MYSQL_HOST: string
        // +ui:description=mysql的端口
        MYSQL_PORT: string
    }
}