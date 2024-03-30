"bdos-cluster-role": {
	annotations: {}
	attributes: workload: definition: {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "ClusterRole"
	}
	description: "Patch bdos-cluster-role for bdos application"
	labels: {}
	type: "component"
}
template: {
	output: {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "ClusterRole"
		metadata: name: context.name
		if parameter["rules"] != _|_ {
			rules: parameter["rules"]
		}
	}
	parameter: {
		// +usage=Specify the ClusterRole rules.
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
