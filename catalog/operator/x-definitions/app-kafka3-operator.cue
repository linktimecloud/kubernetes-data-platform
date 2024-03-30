"kafka-3-operator": {
	annotations: {}
	labels: {}
	attributes: {
		"dynamicParameterMeta": [],
		apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "Application"
				type:       "kafka-3-operator"
			}
		}
	}
	description: "kafka-operator-kraft xdefinition"
	type:        "xdefinition"
}

template: {
	output: {
		"apiVersion": "core.oam.dev/v1beta1"
		"kind":       "Application"
		"metadata": {
			"name":      context["name"]
			"namespace": context["namespace"]
		}
		"spec": {
			"components": [
				{
					"name": "kafka-operator-kraft"
					"properties": {
						"chart":           "strimzi-kafka-operator"
						"releaseName":     context["name"]
						"repoType":        "oci"
						"targetNamespace": context["namespace"]
						"url":             context["helm_repo_url"]
						"values": {
							"defaultImageRegistry":   context["docker_registry"]
							"defaultImageRepository": "kafka"
							"defaultImageTag":        parameter.version
							"featureGates": ""
							"image": {
								"imagePullPolicy":  "IfNotPresent"
								"imagePullSecrets": context["K8S_IMAGE_PULL_SECRETS_NAME"]
								"tag":              parameter.version
							}
							"kafkaInit": {
								"image": {
									"tag": parameter.version
								}
							}
							"logLevel": "INFO"
							"resources": {
								"limits": {
									"cpu":    parameter.resources.limits.cpu
									"memory": parameter.resources.limits.memory
								}
								"requests": {
									"cpu":    parameter.resources.requests.cpu
									"memory": parameter.resources.requests.memory
								}
							}
							"watchAnyNamespace": true
						}
						"version": parameter.version
					}
					"type": "helm"
				},
			]
		}
	}
	parameter: {
		// +ui:description=资源规格
		// +ui:order=2
		resources: {
			// +ui:description=限制
			// +ui:order=1
			limits: {
				// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
				// +ui:order=1
				// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
				cpu: *"2" | string
				// +pattern=^[1-9]\d*(Mi|Gi)$
				// +ui:order=1
				// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
				memory: *"2048Mi" | string
			}
			// +ui:description=预留
			// +ui:order=2
			requests: {
				// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
				// +ui:order=1
				// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
				cpu: *"0.5" | string
				// +pattern=^[1-9]\d*(Mi|Gi)$
				// +ui:order=2
				// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
				memory: *"2048Mi" | string
			}
		}
		// +ui:description=helm chart版本
		// +ui:order=10000
		// +ui:options={"disabled":true}
		version: *"v1.0.0-0.34.0-3" | string
	}
}
