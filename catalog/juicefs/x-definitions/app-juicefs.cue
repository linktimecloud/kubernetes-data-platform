import "strings"

"juicefs": {
	annotations: {}
	labels: {}
	attributes: {
		apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "Application"
				type:       "juicefs"
			}
		}
	}
	description: "juicefs"
	type:        "xdefinition"
}

template: {
	_databaseName:  "\(strings.Replace(context.namespace+"_juicefs", "-", "_", -1))"
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
						chart:           "juicefs-s3-gateway"
						releaseName:     context["name"]
						repoType:        "oci"
						targetNamespace: context["namespace"]
						url:             context["helm_repo_url"]
						values: {
							image: {
								repository: "\(_imageRegistry)juicedata/mount"
								tag:        "ce-v1.1.0"
							}
							secret: {
								name:      "jfs-volume"
								metaurl:   ""
								storage:   "minio"
								accessKey: "admin"
								secretKey: "admin.password"
								bucket:    "http://minio:9000/juicefs"
							}
							options: "--multi-buckets"
						}
						version: "0.11.2"
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
												serviceName: "juicefs-s3-gateway"
												servicePort: 9000
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
						{
							properties: {
								endpoints: [
									{
										path:     "/metrics"
										port:     9567
										portName: "juicefs-s3-gateway"
									},
								]
								// matchLabels: {
								//  "app.kubernetes.io/instance": "minio"
								//  "app.kubernetes.io/name":     "minio"
								// }
								monitortype: "service"
								namespace:   context["namespace"]
							}
							type: "bdos-monitor"
						},

					]
					type: "helm"
				},

				{
					name: context["name"] + "-context"
					type: "k8s-objects"
					properties: {
						objects: [{
							apiVersion: "bdc.kdp.io/v1alpha1"
							kind:       "ContextSetting"
							metadata: {
								annotations: {
									"setting.ctx.bdc.kdp.io/origin": "system"
									"setting.ctx.bdc.kdp.io/type":   "juicefs"
								}
								name:      context["namespace"] + "-" + context["name"] + "-context"
								namespace: context["namespace"]
							}
							spec: {
								name: context["name"] + "-context"
								properties: {
									authSecretName: "juicefs-secret"
									host:           context["name"] + "." + context["namespace"] + ".svc.cluster.local:9000"
								}
								type: "juicefs"
							}
						}]

					}
				},

			]
			policies: [
				{
					name: "shared-resource"
					properties: {
						rules: [
							{
								selector: {
									componentNames: [
										// "minio-grafana-dashboard",
									]
								}
							},
						]
					}
					type: "shared-resource"
				},
			]
		}
	}

	parameter: {
		// +ui:title=部署模式
		// +ui:description="standalone"模式仅用于测试，生产环境请使用"distributed"
		// +ui:order=1
		mode: "distributed" | "standalone"

		// +ui:title=存储配置
		// +ui:description=仅在"distributed"模式下生效
		// +ui:hidden={{rootFormData.mode == "standalone"}}
		// +ui:order=2
		persistence: {
			// +ui:hidden=true
			enabled: *true | bool
			// +ui:description=每个节点的存储大小，请提前规划。可以增大存储大小，不支持减小存储大小。
			// +pattern=^([1-9]\d*)(Ti|Gi|Mi)$
			// +err:options={"pattern":"请输入正确格式，如1024Mi, 1Gi, 1Ti"}
			size: *"1Gi" | string
		}

		// +ui:title=节点配置
		// +ui:description=仅在"distributed"模式下生效
		// +ui:hidden={{rootFormData.mode == "standalone"}}
		// +ui:order=3
		statefulset: {
			// +minimum=4
			// +ui:description=每个Zone节点数量，生产环境至少4个节点。注意：发布后请不要修改副本数，请提前规划。 
			replicaCount: *4 | int

			// minimum=1
			// +ui:description=Zone数量，水平扩容时请增加Zone数量，不支持减少Zone数量。注意：不要随意修改Zone数量。
			zones: *1 | int
		}

		// +ui:description=资源规格
		// +ui:order=5
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

		// +ui:title=管理员账号
		// +ui:order=7
		auth: {
			// +ui:description=管理员账号
			// +ui:options={"showPassword":true}
			rootUser: *"admin" | string

			// +ui:description=管理员密码
			// +ui:options={"showPassword":true}
			rootPassword: *"admin.password" | string
		}
	}
}
