package main

import "strings"

// controller images prefix
_base:    *"" | string
registry: *"" | string
if parameter.registry != _|_ {
	registry: parameter.registry
}

if registry != "" && !strings.HasSuffix(registry, "/") {
	_base: registry + "/"
}
if registry == "" || strings.HasSuffix(registry, "/") {
	_base: registry
}

_targetNamespace: parameter.namespace

gitOpsController: [...] | []

kustomizeResourcesCRD: [...] | []

if parameter.onlyHelmComponents == false {
	gitOpsController: [imageAutomationController, imageReflectorController, kustomizeController]
	kustomizeResourcesCRD: [imagePolicyCRD, imageRepoCRD, imageUpdateCRD, kustomizeCRD]
}

output: {
	apiVersion: "core.oam.dev/v1beta1"
	kind:       "Application"
	spec: {
		components: [
				{
				type: "k8s-objects"
				name: "fluxcd-ns"
				properties: objects: [{
					apiVersion: "v1"
					kind:       "Namespace"
					metadata: name: _targetNamespace
				}]
			},
			{
				type: "k8s-objects"
				name: "fluxcd-rbac"
				properties: objects: [
					// auto-generated from original yaml files
					bindingClusterAdmin,
				]
			},
			{
				type: "k8s-objects"
				name: "fluxcd-CRD"
				properties: objects: [
							// auto-generated from original yaml files
							bucketCRD,
							gitRepoCRD,
							ociRepoCRD,
							helmChartCRD,
							helmReleaseCRD,
							helmRepoCRD,
				] + kustomizeResourcesCRD
			},
			helmController,
			sourceController,
		] + gitOpsController
		policies: [
			{
				type: "shared-resource"
				name: "shared-CRD-namespace"
				properties: rules: [{
					selector: resourceTypes: ["CustomResourceDefinition", "Namespace"]
				}]
			},
			{
				type: "take-over"
				name: "take-over-CRD-namespace"
				properties: rules: [{
					selector: resourceTypes: ["CustomResourceDefinition", "Namespace"]
				}]
			},
			{
				type: "topology"
				name: "deploy-fluxcd"
				properties: {
					namespace: _targetNamespace
					if parameter.clusters != _|_ {
						clusters: parameter.clusters
					}
					if parameter.clusters == _|_ {
						clusterLabelSelector: {}
					}
				}
			},
			{
				type: "garbage-collect"
				name: "not-gc-CRD-namespace"
				properties: {
					rules: [{
						selector: resourceTypes: ["CustomResourceDefinition", "Namespace"]
						strategy: "never"
					},
					]
				}
			},
			{
				type: "apply-once"
				name: "not-keep-CRD"
				properties: {
					rules: [{
						selector: resourceTypes: ["CustomResourceDefinition"]
						strategy: {
							path: ["*"]
						}
					},
					]
				}
			},
		]
	}
}
