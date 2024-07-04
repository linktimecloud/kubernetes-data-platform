"ollama": {
	annotations: {}
	labels: {}
	attributes: {
		dynamicParameterMeta: [
		]
		apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "Application"
				type:       "ollama"
			}
		}
	}
	description: "ollama"
	type:        "xdefinition"
}

template: {
	_imageRegistry: *"" | string
	if context.docker_registry != _|_ && len(context.docker_registry) > 0 {
		_imageRegistry: context.docker_registry + "/"
	}
	_ingressHost: context["name"] + "-" + context["namespace"] + "." + context["ingress.root_domain"]

	output: {
		apiVersion: "core.oam.dev/v1beta1"
		kind:       "Application"
		metadata: {
			name:      context["name"]
			namespace: context["namespace"]
		}
		spec: {
			components: [
				{
					name: context["name"]
					properties: {
						chart:           "ollama"
						releaseName:     context["name"]
						repoType:        "oci"
						targetNamespace: context["namespace"]
						url:             context["helm_repo_url"]
						version:         "0.40.0"
						values: {
							image: {
								repository: "\(_imageRegistry)ollama/ollama"
							}
							replicaCount: parameter.replicaCount
							ollama: {
								gpu: {
									enabled: parameter.ollama.gpu.enabled
									// -- GPU type: 'nvidia' or 'amd'
									// If 'ollama.gpu.enabled', default value is nvidia
									// If set to 'amd', this will add 'rocm' suffix to image tag if 'image.tag' is not override
									// This is due cause AMD and CPU/CUDA are different images
									type: "\(parameter.ollama.gpu.type)"

									//-- Specify the number of GPU
									"number": parameter.ollama.gpu.number
								}
								//-- List of models to pull at container startup
								// models: [
								//  "phi3:3.8b",
								//  "qwen:0.5b",
								// ]

								models: parameter.ollama.models
							}

							persistentVolume: {
								enabled:      parameter.persistentVolume.enabled
								size:         parameter.persistentVolume.size
								storageClass: context["storage_config.storage_class_mapping.local_disk"]
							}

							if parameter.resources != _|_ {
								resources: parameter.resources
							}
							if parameter.affinity != _|_ {
								affinity: parameter.affinity
							}
						}
					}
					traits: [
						{
							properties: {
								rules: [
									{
										host: _ingressHost
										paths: [
											{
												path:        "/"
												serviceName: "ollama"
												servicePort: 11434
											},
										]
									},

								]
								tls: [
									{
										hosts: [
											_ingressHost,
										]
										tlsSecretName: context["ingress.tls_secret_name"]
									},
								]
							}
							type: "bdos-ingress"
						},
					]
					type: "helm"
				},
			]
		}
	}

	parameter: {

		// +minimum=1
		// +ui:description=副本数
		// +ui:order=1
		replicaCount: *1 | int

		// +ui:description=Ollama 配置
		// +ui:order=2
		ollama: {
			// +ui:description= GPU 配置
			// +ui:order=1
			gpu: {
				// +ui:description=是否开启GPU
				// +ui:order=1
				enabled: *false | bool

				// +ui:description=GPU类型
				// +ui:order=2
				// type: "nvidia" | "amd"
				type: "nvidia" | "amd"

				// +minimum=1
				// +ui:description=GPU数量
				// +ui:order=3
				"number": *1 | int
			}
			models: [...string]

			// models: ["qwen:0.5b", "nomic-embed-text:v1.5", ...string]
		}

		// +ui:description=持久化配置
		// +ui:order=3
		persistentVolume: {
			// +ui:description=是否开启持久化
			// +ui:order=1
			enabled: *true | bool

			// +ui:description=持久化大小
			// +ui:order=2
			size: *"10Gi" | string
		}

		// +ui:description=资源规格
		// +ui:order=4
		resources: {
			// +ui:description=预留
			// +ui:order=1
			requests: {
				// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
				// +err:options={"pattern":"请输入正确的CPU格式，如0.25，250m"}
				// +ui:description=CPU
				cpu: *"0.1" | string

				// +pattern=^[1-9]\d*(Mi|Gi)$
				// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
				// +ui:description=内存
				memory: *"128Mi" | string
			}
			// +ui:description=限制
			// +ui:order=2
			limits: {
				// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
				// +err:options={"pattern":"请输入正确的CPU格式，如0.25，250m"}
				// +ui:description=CPU
				cpu: *"1" | string

				// +pattern=^[1-9]\d*(Mi|Gi)$
				// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
				// +ui:description=内存
				memory: *"4Gi" | string
			}
		}

		// +ui:description=配置kubernetes亲和性和反亲和性，请根据实际情况调整
		// +ui:order=7
		affinity?: {}

	}
}
