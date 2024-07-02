package main

_kdpTraefikMiddleware: {
	name: parameter.namePrefix + "traefik-middleware"
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
