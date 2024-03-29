"bdos-sidecar": {
	annotations: {}
	attributes: {
		appliesToWorkloads: ["*"]
		podDisruptive: true
	}
	description: "Inject a sidecar container to K8s pod for your workload which follows the pod spec in path 'spec.template'."
	labels: {}
	type: "trait"
}

template: {
	patch: {
		// +patchKey=name
		spec: template: spec: containers: [{
			name:  parameter.name
			image: parameter.image
			if parameter["imagePullPolicy"] != _|_ {
				imagePullPolicy: parameter.imagePullPolicy
			}
			if parameter.cmd != _|_ {
				command: parameter.cmd
			}
			if parameter.args != _|_ {
				args: parameter.args
			}
			if parameter["securityContext"] != _|_ {
			    securityContext: parameter.securityContext
			}
			if parameter["env"] != _|_ {
				env: parameter.env
			}
			if parameter["cpu"] != _|_ {
				resources: {
					limits: cpu:   parameter.cpu
					requests: cpu: parameter.cpu
				}
			}

			if parameter["memory"] != _|_ {
				resources: {
					limits: memory:   parameter.memory
					requests: memory: parameter.memory
				}
			}

			// +patchKey=name
			if parameter["volumes"] != _|_ {
				volumeMounts: [ for v in parameter.volumes {
					{
						mountPath: v.mountPath
						name:      v.name
						if v.readOnly != _|_ {
							readOnly: v.readOnly
						}
						if v.subPath != _|_ {
							subPath: v.subPath
						}
					}}]
			}
		}]
		spec: template: spec: {
			if parameter["imagePullSecrets"] != _|_ {
				imagePullSecrets: [ for v in parameter.imagePullSecrets {
					name: v
				},
				]
			}
			if parameter["volumes"] != _|_ {
				// +patchKey=name
				volumes: [ for v in parameter.volumes {
					{
						name: v.name
						if v.type == "pvc" {
							persistentVolumeClaim: {
								claimName: v.claimName
							}
						}
						if v.type == "configMap" {
							configMap: {
								defaultMode: v.defaultMode
								name:        v.cmName
								if v.items != _|_ {
									items: v.items
								}
							}
						}
						if v.type == "secret" {
							secret: {
								defaultMode: v.defaultMode
								secretName:  v.secretName
								if v.items != _|_ {
									items: v.items
								}
							}
						}
						if v.type == "emptyDir" {
							emptyDir: {
								medium: v.medium
							}
						}
						if v.type == "host" {
							hostPath: {
								path: v.hostPath
							}
						}
						if v.type == "downwardAPI" {
							downwardAPI: {
								if v.items != _|_ {
									items: v.items
								}
							}
						}
					}}]
			}
		}
	}
	parameter: {
		// +usage=Specify the name of sidecar container
		name: string

		// +usage=Specify the image of sidecar container
		image: string

		// +usage=Specify image pull policy for your service
		imagePullPolicy?: string

		// +usage=Specify image pull secrets for your service
		imagePullSecrets?: [...string]

		// +usage=Specify the commands run in the sidecar
		cmd?: [...string]

		// +usage=Specify the args in the sidecar
		args?: [...string]

		// +usage=Specify securityContext for sidecar container
		securityContext?: *{} | {...}

		// +usage=Declare volumes and volumeMounts
		volumes?: [...{
			name:      string
			mountPath: string
			readOnly?: bool
			subPath?:  string
			// +usage=Specify volume type, options: "pvc","configMap","secret","emptyDir","host","downwardAPI"
			type: "pvc" | "configMap" | "secret" | "emptyDir" | "host" | "downwardAPI"
			if type == "pvc" {
				claimName: string
			}
			if type == "configMap" {
				defaultMode: *420 | int
				cmName:      string
				items?: [...{
					key:  string
					path: string
					mode: *511 | int
				}]
			}
			if type == "secret" {
				defaultMode: *420 | int
				secretName:  string
				items?: [...{
					key:  string
					path: string
					mode: *511 | int
				}]
			}
			if type == "emptyDir" {
				medium: *"" | "Memory"
			}
			if type == "host" {
				hostPath: string
			}
			if type == "downwardAPI" {
				items?: [...{
					path: string
					// +usage=Required: Selects a field of the pod: only annotations, labels, name and namespace are supported.
					fieldRef?: {
						// +usage=Path of the field to select in the specified API version.
						fieldPath: string
					}
					// +usage=Selects a resource of the container: only resources limits and requests (limits.cpu, limits.memory, requests.cpu and requests.memory) are currently supported.
					resourceFieldRef?: {
						// +usage=Container name: required for volumes, optional for env vars
						containerName: string
						// +usage=Required: resource to select
						resource: string
						// +usage=Specifies the output format of the exposed resources, defaults to "1"
						divisor: string
					}
				}]
			}
		}]

		// +usage=Define arguments by using environment variables
		env?: [...{
			// +usage=Environment variable name
			name: string
			// +usage=The value of the environment variable
			value?: string
			// +usage=Specifies a source the value of this var should come from
			valueFrom?: {
				// +usage=Selects a key of a secret in the pod's namespace
				secretKeyRef?: {
					// +usage=The name of the secret in the pod's namespace to select from
					name: string
					// +usage=The key of the secret to select from. Must be a valid secret key
					key: string
				}
				// +usage=Selects a key of a configmap in the pod's namespace
				configMapKeyRef?: {
					// +usage=The name of the configmap in the pod's namespace to select from
					name: string
					// +usage=The key of the configmap to select from. Must be a valid configmap key
					key: string
				}
			}
		}]
		// +usage=Number of CPU units for the service, like `0.5` (0.5 CPU core), `1` (1 CPU core)
		cpu?: string
		// +usage=Specifies the attributes of the memory resource required for the container.
		memory?: string
	}
}
