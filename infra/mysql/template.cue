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

output: {
	apiVersion: "core.oam.dev/v1beta1"
	kind:       "Application"
	metadata: name: context.metadata.name
	spec: {
		components: [_ns] + mysqlComponents
		
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
					},
				]
			},
			{
				type: "take-over"
				name: "take-over-res"
				properties: rules: [
					{
						selector: resourceTypes: [
							"Namespace", 
							"ConfigMap",
							"CustomResourceDefinition", 
							"PersistentVolumeClaim",
							"Service",
							"Secret",
							"CronJob",

						]
						strategy: "never"
					},
				]
			},
			{
				type: "apply-once"
				name: "apply-once-res"
				properties: rules: [
					{
						selector: resourceTypes: [
							"Namespace", 
							"CustomResourceDefinition",
							"Job",
							"CronJob"
						]
						strategy: {
							path: ["*"]
						}
					}
				]
			},
			{
				type: "override"
				name: parameter.namePrefix + "mysql-ns"
				properties: selector: [parameter.namePrefix + "mysql-ns"]
			},
		] + mysqlPolicies

		workflow: steps: [
			{
				type: "deploy"
				name: "deploy-ns"
				properties: policies: [parameter.namePrefix + "mysql-ns"]
			},
		] + mysqlWorkflowSteps
	}
}
