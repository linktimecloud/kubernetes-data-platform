package main

_base: string
_rules: [...]
controllerArgs: [...]
_targetNamespace: string

imageReflectorController: {
	// About this name, refer to #429 for details.
	name: "fluxcd-image-reflector-controller"
	type: "webservice"
	dependsOn: ["fluxcd-ns"]
	properties: {
		imagePullPolicy: "IfNotPresent"
		image:           _base + "fluxcd/image-reflector-controller:v0.23.1"
		env: [
			{
				name:  "RUNTIME_NAMESPACE"
				value: _targetNamespace
			},
		]
		livenessProbe: {
			httpGet: {
				path: "/healthz"
				port: 9440
			}
			timeoutSeconds: 5
		}
		readinessProbe: {
			httpGet: {
				path: "/readyz"
				port: 9440
			}
			timeoutSeconds: 5
		}
		volumeMounts: {
			emptyDir: [
				{
					name:      "temp"
					mountPath: "/tmp"
				},
				{
					name:      "data"
					mountPath: "/data"
				},
			]
		}
		ports: [
			{
				name: "http-prom"
				port: 8080
				expose: false
				protocol: "TCP"
			},
		]
	}
	traits: [
		{
			type: "service-account"
			properties: {
				name:       "sa-image-reflector-controller"
				create:     true
				privileges: _rules
			}
		},
		{
			type: "labels"
			properties: {
				"control-plane": "controller"
				// This label is kept to avoid breaking existing 
				// KubeVela e2e tests (makefile e2e-setup).
				"app": "image-reflector-controller"
			}
		},
		{
			type: "command"
			properties: {
				if parameter.imageReflectorControllerOptions != _|_ {
					args: controllerArgs + parameter.imageReflectorControllerOptions
				}
				if parameter.imageReflectorControllerOptions == _|_ {
					args: controllerArgs
				}
			}
		},
	]
}
