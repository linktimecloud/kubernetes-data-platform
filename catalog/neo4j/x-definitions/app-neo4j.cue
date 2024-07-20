neo4j: {
	annotations: {}
	labels: {}
	attributes: {}
	description: "neo4j xdefinition"
	type:        "xdefinition"
}

template: {
	_imageRegistry: *"" | string
	if context.docker_registry != _|_ && len(context.docker_registry) > 0 {
		_imageRegistry: context.docker_registry + "/"
	}

	output: {
		apiVersion: "core.oam.dev/v1beta1"
		kind:       "Application"
		metadata: {
			name:      context.name
			namespace: context.namespace
			labels: {
				app:                  context.name
				"app.core.bdos/type": "system"
			}
		}
		spec: {
			components: [
				{
					name: context.name
					type: "helm"
					properties: {
						chart:           "neo4j"
						version:         parameter.chartVersion
						url:             context["helm_repo_url"]
						repoType:        "oci"
						releaseName:     context.name
						targetNamespace: context.namespace
						values: {
							"neo4j": {
								name:     context.name
								password: "password"
								resources: {
									cpu:    parameter.resources.cpu
									memory: parameter.resources.memory
								}
							}
							"image": {
								"customImage": _imageRegistry + "neo4j:" + parameter.imageTag
							}
							"volumes": {
								"data": {
									"mode": "dynamic"
									"dynamic": {
										"storageClassName": context["storage_config.storage_class_mapping.local_disk"]
										"accessModes": [
											"ReadWriteOnce",
										]
										"requests": {
											"storage": parameter.persistence.size
										}
									}
								}
							}
							"services": {
								"neo4j": {
									"cleanup": {
										"enabled": false
									}
								}
							}
							"podSpec": {
								serviceAccountName: context.name
							}
						}
					}
					traits: [
						{
							properties: {
								name: context["name"]
							}
							type: "bdos-service-account"
						},
						{
							properties: {
								rules: [
									{
										host: context["name"] + "-" + context["namespace"] + "." + context["ingress.root_domain"]
										paths: [
											{
												path:        "/"
												servicePort: 7474
												serviceName: context["name"]
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
				},
			]
		}
	}

	parameter: {

		// +ui:description=资源规格
		// +ui:order=1
		resources: {
			// +ui:description=CPU
			// +ui:order=1
			// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
			// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
			cpu: *"1" | string
			// +ui:description=内存
			// +ui:order=2
			// +pattern=^[1-9]\d*(Mi|Gi)$
			// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
			memory: *"2Gi" | string
		}

		// +ui:description=持久化存储配置
		// +ui:order=2
		persistence: {
			// +ui:description=持久卷大小
			// +pattern=^([1-9]\d*)(Ti|Gi|Mi)$
			// +err:options={"pattern":"请输入正确的存储格式，如1Gi"}
			size: *"1Gi" | string
		}

		// +ui:description=Helm Chart 版本号
		// +ui:order=100
		// +ui:options={"disabled":true}
		chartVersion: *"5.21.2" | string

		// +ui:description=镜像版本
		// +ui:order=101
		// +ui:options={"disabled":true}
		imageTag: *"5.21.2-community" | string
	}
}
