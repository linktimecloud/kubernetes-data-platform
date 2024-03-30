"ctx-setting-hdfs": {
    description: "Init hdfs context setting resource"
    type:        "xdefinition"
    attributes: {
        apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "ContextSetting"
				type:       "hdfs"
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
            "core-site.xml": parameter.coreSite
            "hdfs-site.xml": parameter.hdfsSite
            "yarn-site.xml": parameter.yarnSite
            "webhdfs": parameter.webhdfs
        }
    }
    parameter: {
        coreSite: string
        hdfsSite: string
        yarnSite: string
        webhdfs: string
    }
}