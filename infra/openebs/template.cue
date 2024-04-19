package main

_ns: {
	name: parameter.namePrefix + "ns"
	type: "k8s-objects"
	properties: objects: [{
		apiVersion: "v1"
		kind:       "Namespace"
		metadata: name: parameter.namespace
	}]
}

_openebs: {
	name: parameter.namePrefix + "openebs"
	type: "helm"
	properties: {
		url:             "\(parameter.helmURL)"
		chart:           "openebs"
		version: 		 "3.10.0"
		releaseName:     parameter.namePrefix + "openebs"
		repoType:        "oci"
		targetNamespace: "\(parameter.namespace)"
		values: {
            release: version: "3.10.0"
            image: {
				pullPolicy: "IfNotPresent"
                repository: "\(parameter.registry)/"
            	imagePullSecrets: [
                	{name: "\(parameter.imagePullSecret)"}
            	]
			}
            localprovisioner: {
                enabled: true
                image: "openebs/provisioner-localpv"
                imageTag: "3.5.0"
                replicas: 3
                basePath: "/var/openebs/local"
                deviceClass: {
                    enabled: false
                    name: "openebs-device"
                }
                hostPathClass: {
                    enabled: true
                    name: "openebs-hostpath"
                }
            }  
            ndm: {
                enabled: true
                image: "openebs/node-disk-manager"
                imageTag: "2.1.0"
                nodeSelector: {}
                tolerations: []
            }
            ndmOperator: {
                enabled: true
                image: "openebs/node-disk-operator"
                imageTag: "2.1.0"
                replicas: 1
            }
            webhook: {
                enabled: true
                image: "openebs/admission-server"
                imageTag: "2.12.2"
                failurePolicy: "Fail"
                replicas: 1
            }
        }
	}
}

output: {
	apiVersion: "core.oam.dev/v1beta1"
	kind: "Application"
	metadata: name: context.metadata.name
	spec: {
		components: [
			_ns,
			_openebs
		]
		policies: [
			{
				type: "shared-resource"
				name: "shared-res"
				properties: rules: [
					{
						selector: resourceTypes: ["Namespace", "CustomResourceDefinition"]
					}
				]
			},
			{
				type: "garbage-collect"
				name: "gc-excluded-res"
				properties: rules: [
					{
						selector: resourceTypes: ["Namespace", "CustomResourceDefinition"]
						strategy: "never"
					}
				]
			},
			{
				type: "apply-once"
				name: "apply-once-res"
				properties: rules: [
					{
						selector: resourceTypes: ["Namespace", "CustomResourceDefinition"]
						strategy: {
							path: ["*"]
						}
					}
				]
			}
		]
	}
}
