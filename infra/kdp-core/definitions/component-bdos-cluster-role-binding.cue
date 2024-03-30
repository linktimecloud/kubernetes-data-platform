"bdos-cluster-role-binding": {
	annotations: {}
	attributes: workload: definition: {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "ClusterRoleBinding"
	}
	description: "Patch bdos-cluster-role-binding for bdos application"
	labels: {}
	type: "component"
}
template: {
	output: {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "ClusterRoleBinding"
		metadata: name: context.name
		"roleRef": {
			"apiGroup": "rbac.authorization.k8s.io"
			"kind":     "ClusterRole"
			"name":     parameter.clusterRoleRefName
		}
		if parameter["serviceAccounts"] != _|_ {
			subjects: [ for v in parameter.serviceAccounts {
				{
					"kind":      "ServiceAccount"
					"name":      v.serviceAccountName
					"namespace": v.namespace
				}},
			]
		}
	}
	parameter: {
		// +usage=Specify the role-binding's role name.
		clusterRoleRefName: string
		// +usage=Specify the role-binding's serviceAccounts properties.
		serviceAccounts?: [...{
			serviceAccountName?: *"default" | string
			namespace?:          *"default" | string
		}]
	}
}
