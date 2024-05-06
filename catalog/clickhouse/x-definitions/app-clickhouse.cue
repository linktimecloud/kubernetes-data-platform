"clickhouse": {
	annotations: {}
	labels: {}
	attributes: {
		"dynamicParameterMeta": [
      {
				"name":        "dependencies.zookeeperHost"
				"type":        "ContextSetting"
				"refType":     "zookeeper"
				"refKey":      "hostname"
				"description": "zookeeper host"
				"required":    true
			}
		]
		apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "Application"
				type:       "clickhouse"
			}
		}
	}
	description: "clickhouse xdefinition"
	type:        "xdefinition"
}

template: {
	output: {
		apiVersion: "core.oam.dev/v1beta1"
		kind:       "Application"
		metadata: {
			name:      context.name
			namespace: context.namespace
			labels: {
				"app":                context.name
				"app.core.bdos/type": "system"
			}
		}
		spec: {
			components: [
				{
					name: context.name
					type: "helm"
					properties: {
						chart:           "clickhouse"
						version:         parameter.chartVersion
						url:             context.helm_repo_url
						repoType:        "oci"
						releaseName:     context.name
						targetNamespace: context.namespace
						values: {
              image: {
                registry: context.docker_registry
                tag: parameter.imageTag
              }
              shards: parameter.shards
              replicaCount: parameter.replicaCount
              resources: parameter.resources
              auth: {
                username: parameter.auth.username
                password: parameter.auth.password
              }
              podAntiAffinityPreset: "soft"
              persistence: {
                enabled: true
                storageClass: context["storage_config.storage_class_mapping.local_disk"]
                size: parameter.storageSize
              }
              metrics: enabled: true
              zookeeper: enabled: false
              externalZookeeper: {
                servers: [
                  parameter.dependencies.zookeeperHost
                ]
                port: 2181
              }
            }
					}
					traits: [
						{
							type: "bdos-monitor"
							properties: {
								monitortype: "pod"
								endpoints: [
									{
										port:     8001
										portName: "http-metrics"
									},
								]
								matchLabels: {
									"app.kubernetes.io/instance": context.name
								}
							}
						},
					]
				},
			]
			policies: []
		}
	}
	parameter: {
    // +ui:description=副本数
		// +ui:order=1
		// +minimum=1
    shards: *2 | int
		// +ui:description=副本数
		// +ui:order=2
		// +minimum=1
		replicaCount: *2 | int
    // +ui:description=存储大小
		// +ui:order=3
		// +pattern=^[1-9]\d*(Mi|Gi)$
		// +err:options={"pattern":"请输入正确的存储格式，如1024Mi, 1Gi"}
    storageSize: *"20Gi" | string
		// +ui:description=资源规格
		// +ui:order=4
		resources: {
			// +ui:description=预留
			// +ui:order=1
			requests: {
				// +ui:description=CPU
				// +ui:order=1
				// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
				// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
				cpu: *"0.1" | string
				// +ui:description=内存
				// +ui:order=2
				// +pattern=^[1-9]\d*(Mi|Gi)$
				// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
				memory: *"512Mi" | string
			}
			// +ui:description=限制
			// +ui:order=2
			limits: {
				// +ui:description=CPU
				// +ui:order=1
				// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
				// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
				cpu: *"4.0" | string
				// +ui:description=内存
				// +ui:order=2
				// +pattern=^[1-9]\d*(Mi|Gi)$
				// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
				memory: *"4096Mi" | string
			}
		}
		// +ui:description=clickhouse管理员设置
		// +ui:order=5
		auth: {
			// +ui:description=管理员用户名
			// +ui:order=1
			username: *"default" | string
			// +ui:description=管理员密码。部署后无法在此页面更改密码。
			// +ui:options={"showPassword": true}
			// +ui:order=2
			password: string
		}
		// +ui:description=Helm Chart 版本号
		// +ui:order=100
		// +ui:options={"disabled":true}
		chartVersion: *"6.0.2" | string
		// +ui:description=镜像版本
		// +ui:order=101
		// +ui:options={"disabled":true}
		imageTag: *"24.3.2-debian-12-r2" | string
	}
}
