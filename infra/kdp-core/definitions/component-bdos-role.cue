"bdos-role": {
	annotations: {}
	attributes: workload: definition: {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "Role"
	}
	description: "Patch bdos-role for bdos application"
	labels: {}
	type: "component"
}
template: {
	output: {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "Role"
		metadata: {
			name: context.name
			if parameter.namespace != _|_ {
				namespace: parameter.namespace
			}
		}
		if parameter["rules"] != _|_ {
			rules: parameter["rules"]
		}
	}
	parameter: {
		namespace?: *"default" | string
		// +usage=Specify the Role rules.
		rules?: [...{
			// +usage=Specify the apiGroups.
			apiGroups?: [...string]
			// +usage=Specify the resources.
			resources?: [...string]
			// +usage=Specify the nonResourceURLs.
			nonResourceURLs?: [...string]
			// +usage=Specify the verbs.
			verbs?: [...string]
		},
		]
	}
}
