"mongodb": {
	annotations: {}
	labels: {}
	attributes: {
		dynamicParameterMeta: [
		]
		apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "Application"
				type:       "mongodb"
			}
		}
	}
	description: "mongodb"
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
					type: "helm"
					properties: {
						chart:           "mongodb-sharded"
						releaseName:     context["name"]
						repoType:        "oci"
						targetNamespace: context["namespace"]
						url:             context["helm_repo_url"]
						// https://artifacthub.io/packages/helm/bitnami/mongodb-sharded/8.3.2
						version: "8.3.2"
						values: {
							global: {
								imageRegistry: context["docker_registry"]
								storageClass:  context["storage_config.storage_class_mapping.local_disk"]
							}
							// authtentication
							auth: {
								enabled: true
								rootUser: "root"
								rootPassword: "root.password"
							}
							// config server	
							configsvr: {
								replicaCount: parameter.configServer.replicaCount
								persistence:
									enabled: true
									size: parameter.configServer.persistence.size
								resources: parameter.configServer.resources
								if parameter.affinity != _|_ {
									affinity: parameter.configServer.affinity
								}
							}
							// mongos node
							mongos: {
								replicaCount: parameter.mongos.replicaCount
								resources: parameter.mongos.resources
								if parameter.affinity != _|_ {
									affinity: parameter.mongos.affinity
								}
							}
							// shard node
							shards: parameter.shard.shardCount
							shardsvr: {
								persistence:
									enabled: true
									size: parameter.shard.persistence.size
								dataNode:
									replicaCount: parameter.shard.replicaCount
									resources: parameter.shard.resources
									if parameter.affinity != _|_ {
									affinity: parameter.shard.affinity
								}
							}

							// metrics pod https://logz.io/blog/mongodb-monitoring-prometheus-best-practices/
							metrics: {
								enabled: true
							}
						}
					}
					traits: [
						
						{
							properties: {
								endpoints: [
									{
										port:     9216
										portName: "metrics"
										path:     "/metrics"
									},
								]
								monitortype: "service"
								namespace:   context["namespace"]
								matchLabels: {
									"app.kubernetes.io/component": "mongos"
									"app.kubernetes.io/name":      "mongodb-sharded"
								}
							}
							type: "bdos-monitor"
						},
						{
							type: "bdos-grafana-dashboard"
							properties: {
								labels: {
									"grafana_dashboard": "1"
								}
								dashboard_data: {
									
								}
							}
						},
					]
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
									"setting.ctx.bdc.kdp.io/type":   "mongodb"
								}
								name:      context["namespace"] + "-" + context["name"] + "-context-setting"
								namespace: context["namespace"]
							}
							spec: {
								name:      context["name"] + "-context-setting"
								_port:     "27017"
								_hostname: context["name"] + "." + context["namespace"] + ".svc.cluster.local"
								properties: {
									hostname: _hostname
									port:     _port
									host:     _hostname + ":" + _port
								}
								type: "mongodb"
							}
						}]
					}
				},
			]
			policies: []
		}
	}

	parameter: {
		// +ui:title=config service 配置
		// +ui:order=1
		configServer: {
			// +minimum=1
			// +ui:description=master 节点数量, 高可用场景建议配置3个
			// +ui:order=1
			replicaCount: *1 | int

			// +ui:title=存储配置
			// +ui:order=2
			persistence: {
				// pattern=^[1-9]\d*(Gi|Mi|Ti)$
				// err:options={"pattern":"请输入正确格式，如1024Mi, 1Gi, 1Ti"}
				// +ui:description=各节点存储大小，请根据实际情况调整
				// +ui:order=2
				// +ui:hidden={{rootFormData.master.persistence.enabled == false}}
				size: *"1Gi" | string
			}

			// +ui:description=资源规格
			// +ui:order=3
			resources: {
				// +ui:description=预留
				// +ui:order=1
				requests: {
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的CPU格式，如0.25，250m"}
					// +ui:description=CPU
					cpu: *"25m" | string

					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					// +ui:description=内存
					memory: *"512Mi" | string
				}

				// +ui:description=限制
				// +ui:order=2
				limits: {
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的CPU格式，如0.25，250m"}
					// +ui:description=CPU
					cpu: *"2" | string

					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					// +ui:description=内存
					memory: *"1Gi" | string
				}
			}

			// +ui:description=配置kubernetes亲和性，请根据实际情况调整
			// +ui:order=4
			affinity?: {}
		}

		// +ui:title=mongos 配置
		// +ui:order=2
		mongos: {
			// +minimum=1
			// +ui:description=master 节点数量, 高可用场景建议配置2个起
			// +ui:order=1
			replicaCount: *1 | int

			// +ui:description=资源规格
			// +ui:order=3
			resources: {
				// +ui:description=预留
				// +ui:order=1
				requests: {
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的CPU格式，如0.25，250m"}
					// +ui:description=CPU
					cpu: *"25m" | string

					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					// +ui:description=内存
					memory: *"256Mi" | string
				}

				// +ui:description=限制
				// +ui:order=2
				limits: {
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的CPU格式，如0.25，250m"}
					// +ui:description=CPU
					cpu: *"2" | string

					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					// +ui:description=内存
					memory: *"1Gi" | string
				}
			}

			// +ui:description=配置kubernetes亲和性，请根据实际情况调整
			// +ui:order=4
			affinity?: {}

		}

		// +ui:title=shard 配置
		// +ui:order=2
		shard: {
			// +minimum=1
			// +ui:description=shard 数量，按需配置
			// +ui:order=1
			shardCount: *2 | int

			// +minimum=1
			// +ui:description=master 节点数量, 高可用场景建议配置3个
			// +ui:order=2
			replicaCount: *2 | int

			// +ui:title=存储配置
			// +ui:order=3
			persistence: {
				// pattern=^[1-9]\d*(Gi|Mi|Ti)$
				// err:options={"pattern":"请输入正确格式，如1024Mi, 1Gi, 1Ti"}
				// +ui:description=各节点存储大小，请根据实际情况调整
				// +ui:hidden={{rootFormData.master.persistence.enabled == false}}
				size: *"8Gi" | string
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
					cpu: *"25m" | string

					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					// +ui:description=内存
					memory: *"256Mi" | string
				}

				// +ui:description=限制
				// +ui:order=2
				limits: {
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的CPU格式，如0.25，250m"}
					// +ui:description=CPU
					cpu: *"2" | string

					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					// +ui:description=内存
					memory: *"1Gi" | string
				}
			}

			// +ui:description=配置kubernetes亲和性，请根据实际情况调整
			// +ui:order=5
			affinity?: {}

		}



		

	}
}
