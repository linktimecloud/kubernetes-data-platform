"bdos-service-account": {
	annotations: {}
	attributes: {
		appliesToWorkloads: ["deployments.apps", "deployments.apps", "statefulsets.apps", "daemonsets.apps", "jobs.batch"]
		podDisruptive: false
	}
	description: "Patch bdos-service-account for bdos application"
	labels: {}
	type: "trait"
}
template: {
	// +patchStrategy=retainKeys
	patch: spec: template: spec: serviceAccountName: parameter.name
	outputs: "\(parameter.name)": {
		apiVersion: "v1"
		kind:       "ServiceAccount"
		metadata: name: parameter.name
		if parameter.namespace != _|_ {
			metadata: namespace: parameter.namespace
		}
	}
	parameter: {
		namespace?: *"default" | string
		// +usage=Specify the ServiceAccount name.
		name?: *"default" | string
	}
}
