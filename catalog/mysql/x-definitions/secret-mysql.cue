"ctx-secret-mysql": {
    description: "Init context secret resource"
    type:        "xdefinition"
    attributes: {
        apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "ContextSecret"
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
        kind: "Secret"
        metadata: {
            name: context.name
            namespace: context.namespace
            annotations: context.bdcAnnotations
        }
        type: "Opaque"
        data: {
            MYSQL_USER: parameter.MYSQL_USER
            MYSQL_PASSWORD: parameter.MYSQL_PASSWORD
        }
    }
    parameter: {
        // +ui:description=设置mysql的用户名
        MYSQL_USER: string
        // +ui:description=设置mysql的密码
        MYSQL_PASSWORD: string
    }
}