package main

_bdcDef: {
    name: parameter.namePrefix + "bdc-definition"
	type: "k8s-objects"
	properties: {
        objects: [
            {
                apiVersion: "bdc.kdp.io/v1alpha1"
                kind: "XDefinition"
                metadata: {
                    name: "bigdatacluster-def"
                    annotations: "definition.bdc.kdp.io/description": "BigdataCluster definition"
                }
                spec: {
                    apiResource: definition: {
                        apiVersion: "bdc.kdp.io/v1alpha1"
                        kind: "BigDataCluster"
                    }
                    schematic: cue: template: """
                    output: {
                        apiVersion: "v1"
                        kind:       "Namespace"
                        metadata: {
                            name: parameter.namespaces[0].name
                            labels: context.bdcLabels
                            annotations: context.bdcAnnotations
                        }
                    }
                    outputs: {
                        for i, v in parameter.namespaces {
                            if i > 0 {
                                "object-\\(i)": {
                                    apiVersion: "v1"
                                    kind:       "Namespace"
                                    metadata: {
                                        name: v.name
                                        annotations: "bdc.kdp.io/name": context.bdcName
                                    }
                                }
                            }
                        }
                    }
                    parameter: {
                        frozen?:   *false | bool
                        disabled?: *false | bool
                        namespaces: [...{
                            name:      string
                            isDefault: bool
                        },]
                    }
                    """
                }
            }
        ]
    }
}

_systemBDC: {
    name: parameter.namePrefix + "system-bdc"
	type: "k8s-objects"
	properties: {
        objects: [
            {
                apiVersion: "bdc.kdp.io/v1alpha1"
                kind: "BigDataCluster"
                metadata: {
                    name: "kdp-data"
                    labels: {
                        "bdc.kdp.io/org": "admin"
                    }
                    annotations: {
                        "bdc.kdp.io/description": "This is a built-in bigdata cluster."
                    }
                }
                spec: {
                    disabled: false
                    frozen: false
                    namespaces: [
                        {
                            name: "kdp-data"
                            isDefault: true
                        }
                    ]
                }
            }
        ]
    }
}
