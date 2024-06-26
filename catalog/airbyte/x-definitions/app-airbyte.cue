"airbyte": {
	annotations: {}
	labels: {}
	attributes: {
		apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "Application"
				type:       "airbyte"
			}
		}
	}
	description: "airbyte"
	type:        "xdefinition"
}

template: {
	_imageRegistry:        *"" | string
	_contextImageRegistry: context["docker_registry"]
	if _contextImageRegistry != _|_ && len(_contextImageRegistry) > 0 {
		_imageRegistry: _contextImageRegistry + "/"
	}

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
						chart:           "airbyte"
						releaseName:     context["name"]
						repoType:        "oci"
						targetNamespace: context["namespace"]
						url:             context["helm_repo_url"]
						values: {
							"airbyte-api-server": image: repository:       _imageRegistry + "airbyte/airbyte-api-server"
							"airbyte-bootloader": image: repository:       _imageRegistry + "airbyte/bootloader"
							"connector-builder-server": image: repository: _imageRegistry + "airbyte/connector-builder-server"
							cron: image: repository:                       _imageRegistry + "airbyte/cron"
							metrics: image: repository:                    _imageRegistry + "airbyte/metrics-reporter"
							minio: image: repository:                      _imageRegistry + "minio/minio"
							"pod-sweeper": image: repository:              _imageRegistry + "bitnami/kubectl"
							postgresql: image: repository:                 _imageRegistry + "airbyte/db"
							server: image: repository:                     _imageRegistry + "airbyte/server"
							temporal: image: repository:                   _imageRegistry + "temporalio/auto-setup"
							webapp: image: repository:                     _imageRegistry + "airbyte/webapp"
							worker: image: repository:                     _imageRegistry + "airbyte/worker"
							"workload-api-server": image: repository:      _imageRegistry + "airbyte/workload-api-server"
							"workload-launcher": image: repository:        _imageRegistry + "airbyte/workload-launcher"

							webapp: {
								replicaCount: 1
							}
							server: {
								replicaCount: 1
							}
							worker: {
								replicaCount: parameter.worker.replicaCount
							}
							"airbyte-api-server": {
								replicaCount: 1
							}
							postgresql: {
								enabled: true
							}
							minio: {
								storage: {
									volumeClaimValue: parameter.minio.storage.size
								}
							}
							postgresql: {
								enabled: true
							}
							if parameter.env_vars != _|_ {
								global: env_vars: parameter.env_vars
							}
						}
						version: "0.67.17"
					}
					traits: [
						{
							properties: {
								rules: [
									{
										host: context["name"] + "-" + context["namespace"] + "." + context["ingress.root_domain"]
										paths: [
											{
												path:        "/"
												serviceName: "airbyte-airbyte-webapp-svc"
												servicePort: 80
											},
										]
									},

								]
								tls: [
									{
										hosts: [
											context["name"] + "-" + context["namespace"] + "." + context["ingress.root_domain"],
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
		// +ui:description=Minio存储配置
		// +ui:order=1
		minio: {
			// +ui:order=1
			storage: {
				// +ui:description=配置存储大小
				// +pattern=^([1-9]\d*)(Ti|Gi|Mi)$
				// +err:options={"pattern":"请输入正确格式，如1024Mi, 1Gi, 1Ti"}
				size: *"500Mi" | string
			}
		}

		// +ui:description=Worker配置
		// +ui:order=2
		worker: {
			// +minimum=1
			// +ui:description=副本数
			replicaCount: *1 | int
		}

		// +ui:description=Webapp配置
		// +ui:order=3
		webapp: {
			// +minimum=1
			// +ui:description=副本数
			replicaCount: *1 | int
		}

		// +ui:description=Server配置
		// +ui:order=4
		server: {
			// +minimum=1
			// +ui:description=副本数
			replicaCount: *1 | int
		}

		// +ui:description= 配置环境变量，如 MAX_SYNC_WORKERS=5
		// +ui:order=5
		env_vars?: {...}
	}
}
