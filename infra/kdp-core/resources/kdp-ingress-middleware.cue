package main

_kdpIngressMiddleware: *[] | [...{...}]

_kdpIngressMiddleware: [
	if parameter.ingress.class == "traefik" {
		{
			name: parameter.namePrefix + "ingress-middleware"
			type: "k8s-objects"
			properties: {
				objects: [
					{
						kind:       "Middleware"
						apiVersion: "traefik.io/v1alpha1"
						metadata: {
							name:      "strippath"
							namespace: "\(parameter.namespace)"
						}
						spec: {
							stripPrefixRegex: {
								regex: [".*"]
							}
						}
					},

				]
			}
		}
	},
]

_kdpIngressMiddlewareWorkflow: *[] | [...{...}]
_kdpIngressMiddlewareWorkflow: [
	if parameter.ingress.class == "traefik" {
		{
			type: "apply-component"
			name: "apply-ingress-middleware"
			properties: component: parameter.namePrefix + "ingress-middleware"
		}
	}]
