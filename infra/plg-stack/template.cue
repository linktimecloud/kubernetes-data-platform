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
	kind: "Application"
	metadata: name: context.metadata.name
	spec: {
		components: [
			_ns,
			_prometheus, 
			if parameter.loki.enabled {
				_loki, 
			},
			if parameter.loki.enabled {
				_promtail,
			}
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
				properties: {
					enable: true
					rules: [
						{
							selector: resourceTypes: ["Namespace", "CustomResourceDefinition"]
							strategy: {
								path: ["*"]
							}
						}
					]
				}
			}
		]
		
		workflow: steps: [
			{
				type: "apply-component"
				name: "apply-ns"
				properties: component: parameter.namePrefix + "ns"
			},
			// apply prometheus, alertmanager and grafana
			{
				type: "apply-component"
				name: "apply-prometheus"
				properties: component: parameter.namePrefix + "prometheus"
			},
			// apply loki and promtail
			if parameter.loki.enabled {
				{
					type: "step-group"
					name: "apply-logging-stack"
					dependsOn: ["apply-prometheus"]
					subSteps: [
						{
							type: "apply-component"
							name: "apply-loki"
							properties: component: parameter.namePrefix + "loki"
						},
						{
							type: "apply-component"
							name: "apply-promtail"
							properties: component: parameter.namePrefix + "promtail"
						}
					]
				}
			}
			
		]
	}
}
