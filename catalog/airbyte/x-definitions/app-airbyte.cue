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
							webapp: {
								replicaCount: 1
							}
							server: {
								replicaCount: 1
							}
							worker: {
								replicaCount: 1
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
	}
}
