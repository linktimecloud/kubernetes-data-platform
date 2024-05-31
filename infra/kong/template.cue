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

_kong: {
	name: parameter.namePrefix + "kong"
	type: "helm"
	properties: {
		url:             "\(parameter.helmURL)"
		chart:           "kong"
		version: 		 "2.29.0"
		releaseName:     parameter.namePrefix + "kong"
		repoType:        "oci"
		targetNamespace: "\(parameter.namespace)"
		values: {
			deployment: {
				kong: enabled: true
				daemonset: false
			}
			image: {
				repository: "\(parameter.registry)/kong"
				tag: "3.4.0"
				pullPolicy: "IfNotPresent"
				pullSecrets: [
					{name: "\(parameter.imagePullSecret)"}
				]
			}
			replicaCount: "\(parameter.kong.replicas)"
			status: {
				enabled: true
				http: {
					enabled: true
					containerPort: 8100
					parameters: []
				}
				tls:{
					enabled: false
					containerPort: 8543
					parameters: []
				}
			}
			proxy: {
				enabled: true
				type: "NodePort"
				http: hostPort: 80
				tls: hostPort: 443
			}
			ingressController: {
				enabled: true
				image:
					repository: "\(parameter.registry)/kong/kubernetes-ingress-controller"
					tag: "2.12"
				ingressClass: "kong"
				ingressClassAnnotations: {
					"ingressclass.kubernetes.io/is-default-class": "true"
				}
			}
			waitImage: {
				enabled: true
				repository: "\(parameter.registry)/bash"
				pullPolicy: "IfNotPresent"
			}
			podDisruptionBudget: {
				enabled: true
				maxUnavailable: "50%"
			}
			serviceMonitor: {
				enabled: false
				labels: {
					release: "prometheus"
				}
			}
			admin: enabled: false
			cluster: enabled: false
			certificates: enabled: false
			udpProxy: enabled: false
			portalapi: enabled: false
			clustertelemetry: enabled: false
		}
	}
}

output: {
	apiVersion: "core.oam.dev/v1beta1"
	kind: "Application"
	metadata: name: context.metadata.name
	spec: {
		components: [
			_ns,
			if parameter.kong.enabled {
				_kong
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
				properties: rules: [
					{
						selector: resourceTypes: ["Namespace", "CustomResourceDefinition"]
						strategy: {
							path: ["*"]
						}
					}
				]
			}
		]
	}
}
