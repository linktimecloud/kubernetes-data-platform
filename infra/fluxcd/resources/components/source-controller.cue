package main

_base: string
_rules: [...]
controllerArgs: [...]
_targetNamespace: string
_sourceControllerName: "fluxcd-source-controller"

imageControllerDefaultArgs: controllerArgs + [
					"--storage-path=/data",
					"--storage-adv-addr=http://" + _sourceControllerName + "." + _targetNamespace + ".svc:9090",
]

sourceController: {
	// About this name, refer to #429 for details.
	name: _sourceControllerName
	type: "webservice"
	dependsOn: ["fluxcd-ns"]
	properties: {
		imagePullPolicy: "IfNotPresent"
		image:           _base + "fluxcd/source-controller:v0.33.0"
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
				path: "/"
				port: 9090
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
				port:     9090
				name:     "http"
				protocol: "TCP"
				expose:   true
			},
			{
				name: "http-prom"
				port: 8080
				expose: false
				protocol: "TCP"
			},
		]
		exposeType: "ClusterIP"
	}
	traits: [
		{
			type: "service-account"
			properties: {
				name:       "sa-source-controller"
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
				"app": "source-controller"
			}
		},
		{
			type: "command"
			properties: {
				if parameter.sourceControllerOptions != _|_ {
					args: imageControllerDefaultArgs + parameter.sourceControllerOptions
				}
				if parameter.sourceControllerOptions == _|_ {
					args: imageControllerDefaultArgs
				}	
			}
		},
	]
}
