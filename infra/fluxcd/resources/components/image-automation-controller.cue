package main

_base: string
_rules: [...]
controllerArgs: [...]
_targetNamespace: string

imageAutomationController: {
	// About this name, refer to #429 for details.
	name: "fluxcd-image-automation-controller"
	type: "webservice"
	dependsOn: ["fluxcd-ns"]
	properties: {
		imagePullPolicy: "IfNotPresent"
		image:           _base + "fluxcd/image-automation-controller:v0.28.0"
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
				name:       "sa-image-automation-controller"
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
				"app": "image-automation-controller"
			}
		},
		{
			type: "command"
			properties: {
				if parameter.imageAutomationControllerOptions != _|_ {
					args: controllerArgs + parameter.imageAutomationControllerOptions
				}
				if parameter.imageAutomationControllerOptions == _|_ {
					args: controllerArgs
				}
			}
		},
	]
}
