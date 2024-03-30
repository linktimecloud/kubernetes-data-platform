"helm-labels": {
	attributes: {
		podDisruptive: false
	}
	description: "Patch labels of Pods created by workloads defined in Helm Charts."
	labels: {
		"ui-hidden": "true"
	}
	type: "trait"
	attributes: {
		appliesToWorkloads: ["HelmRelease.helm.toolkit.fluxcd.io"]
	}
}

template: {
	patch: spec: postRenderers: [{
		kustomize: patchesStrategicMerge: [{
			apiVersion: parameter.apiVersion
			kind:       parameter.kind
			metadata: {
				name:      parameter.name
				namespace: parameter.namespace
			}
			spec: template: metadata: labels: {
				 "app.oam.dev/component": context.name
				 "app.oam.dev/name": context.appName
				 for k, v in parameter.labels {
				 	   (k): v
				 }
			}
		}]
	}]

	parameter: {
		apiVersion: *"apps/v1" | string
		kind:       *"Deployment" | string
		name:       *context.name | string
		namespace:  *context.namespace | string
		labels?:    [string]: string
	}
}
