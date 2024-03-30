"bdos-logtail": {
	annotations: {}
	attributes: {
		appliesToWorkloads: ["*"]
		podDisruptive: true
	}
	description: "Inject a sidecar container to push log to loki."
	labels: {}
	type: "trait"
}

template: {
	patch: {
		metadata: annotations: {"reloader.stakater.com/search": "true"}
		// +patchKey=name
		spec: template: spec: containers: [{
			name: parameter.name + "-promtail-sidecar"
			if parameter.promtail.image == _|_ {
				image: "grafana/promtail:2.9.3"
			}
			if parameter.promtail.image != _|_ {
				image: parameter.promtail.image
			}
			if parameter.promtail.imagePullPolicy != _|_ {
				imagePullPolicy: parameter.promtail.imagePullPolicy
			}
			if parameter.promtail.imagePullPolicy == _|_ {
				imagePullPolicy: "IfNotPresent"
			}
			env: [
				{
					name: "LOKI_PUSH_URL"
					valueFrom: {
						configMapKeyRef: {
							name: "promtail-args"
							key:  "LOKI_PUSH_URL"
						}
					}
				},
				{
					name:  "TZ"
					value: "Asia/Shanghai"
				},
				{
					name:  "PROMTAIL_PORT"
					value: "\(parameter.promtail.listenPort)"
				},
				{
					name:  "PROMTAIL_NAMESPACE"
					value: context.namespace
				},
				{
					name:  "PROMTAIL_APPNAME"
					value: context.appName
				},
				{
					name: "POD_NAME"
					valueFrom: {
						fieldRef: {
							fieldPath: "metadata.name"
						}
					}
				},
				{
					name: "PROMTAIL_LOG_PATH"
					if parameter.path != _|_ {
						if parameter.subdirectory == _|_ {
							value: "\(parameter.path)"
						}
						if parameter.subdirectory != _|_ {
							if parameter.subdirectory != ".**" {
								value: "\(parameter.path)/{\(parameter.subdirectory)}"
							}
							if parameter.subdirectory == ".**" {
								value: "\(parameter.path)/**"
							}
						}
					}
				},
			]
			if parameter.promtail.args == _|_ {
				args: [
					"-config.file=/etc/promtail/config.yaml",
					"-config.expand-env=true",
				]
			}

			if parameter.promtail.args != _|_ {
				args: [
					for v in parameter.promtail.args + [
						"-config.file=/etc/promtail/config.yaml",
						"-config.expand-env=true",
					] {
						"\(v)"
					},
				]
			}
			if parameter.promtail.cpu != _|_ {
				resources: {
					limits: cpu:   parameter.promtail.cpu
					requests: cpu: parameter.promtail.cpu
				}
			}
			if parameter.promtail.cpu == _|_ {
				resources: {
					limits: cpu:   "0.1"
					requests: cpu: "0.1"
				}
			}

			if parameter.promtail.memory != _|_ {
				resources: {
					limits: memory:   parameter.promtail.memory
					requests: memory: parameter.promtail.memory
				}
			}
			if parameter.promtail.memory == _|_ {
				resources: {
					limits: memory:   "128Mi"
					requests: memory: "128Mi"
				}
			}

			// +patchKey=name
			volumeMounts: [
				{
					mountPath: "\(parameter.path)"
					name:      "\(parameter.name)"
				},
				{
					mountPath: "/etc/promtail"
					name:      "promtail-conf"
				},
			]
		}]
		spec: template: spec: {
			if parameter["imagePullSecrets"] != _|_ {
				imagePullSecrets: [
					for v in parameter.promtail.imagePullSecrets {
						name: v
					},
				]
			}

			// +patchKey=name
			volumes: [
				{
					name: "\(parameter.name)"
					emptyDir: {}
				},
				{
					name: "promtail-conf"
					configMap: {
						name: "promtail-conf"
					}
				},
			]

		}
	}

	parameter: {
		// +usage=Specify log path where the loki collect
		name: string
		// +usage=Specify log path where the loki collect
		path: string
		// +usage=Specify log subdirectory where the loki collect
		subdirectory?: string
		// +usage=Specify image of log tail service
		promtail: {
			image: *"grafana/promtail:2.5.0" | string
			// +usage=Specify image server listen port
			listenPort: *3101 | int
			// +usage=Specify image pull secrets for your service
			imagePullSecrets?: [...string]
			// +usage=Specify image pull policy for your service
			imagePullPolicy?: *"IfNotPresent" | string
			// +usage=Specify the args in the sidecar
			args?: [...string]
			// +usage=Number of CPU units for the service, like `0.5` (0.5 CPU core), `1` (1 CPU core)
			cpu?: string
			// +usage=Specifies the attributes of the memory resource required for the container.
			memory?: string
		}
	}
}
