"bdos-role-binding": {
	annotations: {}
	attributes: workload: definition: {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "RoleBinding"
	}
	description: "Patch bdos-role-binding for bdos application"
	labels: {}
	type: "component"
}
template: {
	output: {
		apiVersion: "rbac.authorization.k8s.io/v1"
		kind:       "RoleBinding"
		metadata: {
			name: context.name
			if parameter.namespace != _|_ {
				namespace: parameter.namespace
			}
		}
		"roleRef": {
			"apiGroup": "rbac.authorization.k8s.io"
			"kind":     "Role"
			"name":     parameter.roleName
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
		namespace?: *"default" | string
		// +usage=Specify the role-binding's role name.
		roleName: string
		// +usage=Specify the role-binding's serviceAccounts properties.
		serviceAccounts?: [...{
			serviceAccountName?: *"default" | string
			namespace?:          *"default" | string
		}]
	}
}
