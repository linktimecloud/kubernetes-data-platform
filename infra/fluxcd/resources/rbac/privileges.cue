package main

_rules: [
	{
		apiGroups: [
			"source.toolkit.fluxcd.io",
		]
		resources: [
			"*",
		]
		verbs: [
			"*",
		]
		scope: "cluster"
	},
	{
		apiGroups: [
			"kustomize.toolkit.fluxcd.io",
		]
		resources: [
			"*",
		]
		verbs: [
			"*",
		]
		scope: "cluster"
	},
	{
		apiGroups: [
			"helm.toolkit.fluxcd.io",
		]
		resources: [
			"*",
		]
		verbs: [
			"*",
		]
		scope: "cluster"
	},
	{
		apiGroups: [
			"image.toolkit.fluxcd.io",
		]
		resources: [
			"*",
		]
		verbs: [
			"*",
		]
		scope: "cluster"
	},
	{
		apiGroups: [
			"",
		]
		resources: [
			"namespaces",
			"secrets",
			"configmaps",
			"serviceaccounts",
		]
		verbs: [
			"get",
			"list",
			"watch",
		]
		scope: "cluster"
	},
	{
		apiGroups: [
			"",
		]
		resources: [
			"events",
		]
		verbs: [
			"create",
			"patch",
		]
		scope: "cluster"
	},
	{
		apiGroups: [
			"",
		]
		resources: [
			"configmaps",
		]
		verbs: [
			"get",
			"list",
			"watch",
			"create",
			"update",
			"patch",
			"delete",
		]
		scope: "cluster"
	},
	{
		apiGroups: [
			"",
		]
		resources: [
			"configmaps/status",
		]
		verbs: [
			"get",
			"update",
			"patch",
		]
		scope: "cluster"
	},
	{
		apiGroups: [
			"coordination.k8s.io",
		]
		resources: [
			"leases",
		]
		verbs: [
			"get",
			"list",
			"watch",
			"create",
			"update",
			"patch",
			"delete",
		]
		scope: "cluster"
	},
]
