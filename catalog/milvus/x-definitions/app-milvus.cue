import "strings"

milvus: {
	annotations: {}
	labels: {}
	attributes: {
		dynamicParameterMeta: [
			{
				"name":        "dependencies.kafka.cluster"
				"type":        "ContextSetting"
				"refType":     "kafka"
				"refKey":      "bootstrap_plain"
				"description": "kafka server list"
				"required":    true
			},
			{
				name:        "dependencies.minio.host"
				type:        "ContextSetting"
				refType:     "minio"
				refKey:      "host"
				description: "minio host"
				required:    true
			},
			{
				name:        "dependencies.minio.port"
				type:        "ContextSetting"
				refType:     "minio"
				refKey:      "port"
				description: "minio port"
				required:    true
			},
			{
				name:        "dependencies.minio.accessKey"
				type:        "ContextSecret"
				refType:     "minio"
				refKey:      "root-user"
				description: "minio root user"
				required:    true
			},
			{
				name:        "dependencies.minio.secretKey"
				type:        "ContextSecret"
				refType:     "minio"
				refKey:      "root-password"
				description: "minio root user password"
				required:    true
			},
		]
	}
	description: "milvus xdefinition"
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
						chart:           "milvus"
						version:         parameter.chartVersion
						url:             context["helm_repo_url"]
						repoType:        "oci"
						releaseName:     context.name
						targetNamespace: context.namespace
						values: {
							"cluster": {
								"enabled": parameter.clusterMode
							}
							"image": {
								"all": {
									"repository": _imageRegistry + "milvusdb/milvus"
									"tag":        parameter.images.milvus
									"pullPolicy": "IfNotPresent"
									if parameter["imagePullSecrets"] != _|_ {
										pullSecrets: [for v in parameter.imagePullSecrets {
											v
										},
										]
									}
								}
								"tools": {
									"repository": _imageRegistry + "milvusdb/milvus-config-tool"
									"tag":        parameter.images.tools
									"pullPolicy": "IfNotPresent"
								}
							}
							"ingress": {
								"enabled":     true
								"annotations": null
								"labels": {}
								"rules": [
									{
										"host":     "milvus-" + context.namespace + "." + context["ingress.root_domain"]
										"path":     "/"
										"pathType": "Prefix"
									},
								]
								"tls": []
							}
							"serviceAccount": {
								"create": true
							}
							"metrics": {
								"enabled": true
							}
							"livenessProbe": {
								"enabled":             true
								"initialDelaySeconds": 90
								"periodSeconds":       30
								"timeoutSeconds":      5
								"successThreshold":    1
								"failureThreshold":    5
							}
							"readinessProbe": {
								"enabled":             true
								"initialDelaySeconds": 90
								"periodSeconds":       10
								"timeoutSeconds":      5
								"successThreshold":    1
								"failureThreshold":    5
							}
							"log": {
								"level": "info"
								"file": {
									"maxSize":    300
									"maxAge":     10
									"maxBackups": 20
								}
								"format": "text"
								"persistence": {
									"mountPath": "/milvus/logs"
								}
							}
							"standalone": {
								"replicas":  parameter.standalone.replicas
								"resources": parameter.standalone.resources
								"disk": {
									"enabled": true
									"size": {
										"enabled": false
									}
								}
								"profiling": {
									"enabled": true
								}
								"messageQueue": "rocksmq"
								"persistence": {
									"mountPath": "/var/lib/milvus"
									"enabled":   true
									"annotations": {
										"helm.sh/resource-policy": "keep"
									}
									"persistentVolumeClaim": {
										"existingClaim": ""
										"storageClass":  context["storage_config.storage_class_mapping.local_disk"]
										"accessModes":   "ReadWriteOnce"
										"size":          parameter.standalone.persistence.size
										"subPath":       ""
									}
								}
							}
							"proxy": {
								"enabled":   true
								"replicas":  1
								"resources": parameter.proxy.resources
								"profiling": {
									"enabled": true
								}
							}
							"rootCoordinator": {
								"enabled":   true
								"replicas":  1
								"resources": parameter.rootCoordinator.resources
								"profiling": {
									"enabled": true
								}
								"activeStandby": {
									"enabled": false
								}
							}
							"queryCoordinator": {
								"enabled":   true
								"replicas":  1
								"resources": parameter.queryCoordinator.resources
								"profiling": {
									"enabled": true
								}
								"activeStandby": {
									"enabled": false
								}
							}
							"queryNode": {
								"enabled":   true
								"replicas":  1
								"resources": parameter.queryNode.resources
								"disk": {
									"enabled": true
									"size": {
										"enabled": false
									}
								}
								"profiling": {
									"enabled": true
								}
							}
							"indexCoordinator": {
								"enabled":   true
								"replicas":  1
								"resources": parameter.indexCoordinator.resources
								"profiling": {
									"enabled": true
								}
								"activeStandby": {
									"enabled": false
								}
							}
							"indexNode": {
								"enabled":   true
								"replicas":  1
								"resources": parameter.indexNode.resources
								"profiling": {
									"enabled": true
								}
								"disk": {
									"enabled": true
									"size": {
										"enabled": false
									}
								}
							}
							"dataCoordinator": {
								"enabled":   true
								"replicas":  1
								"resources": parameter.dataCoordinator.resources
								"profiling": {
									"enabled": true
								}
								"activeStandby": {
									"enabled": false
								}
							}
							"dataNode": {
								"enabled":   true
								"replicas":  1
								"resources": parameter.dataNode.resources
								"profiling": {
									"enabled": false
								}
							}
							"mixCoordinator": {
								"enabled": false
							}
							"attu": {
								"enabled": true
								"name":    "attu"
								"image": {
									"repository": _imageRegistry + "zilliz/attu"
									"tag":        parameter.images.attu
									"pullPolicy": "IfNotPresent"
								}
								"resources": parameter.attu.resources
								"ingress": {
									"enabled": true
									"annotations": {}
									"labels": {}
									"hosts": [
										"milvus-attu-" + context.namespace + "." + context["ingress.root_domain"],
									]
									"tls": []
								}
							}
							"minio": {
								"enabled": false
							}
							"etcd": {
								"enabled":      true
								"replicaCount": parameter.etcd.replicas
								"image": {
									"registry":   context.docker_registry
									"repository": "milvusdb/etcd"
									"tag":        "3.5.5-r4"
									"pullPolicy": "IfNotPresent"
									if parameter["imagePullSecrets"] != _|_ {
										pullSecrets: [for v in parameter.imagePullSecrets {
											v
										},
										]
									}
								}
								resources: parameter.etcd.resources
								"persistence": {
									"enabled":      true
									"storageClass": context["storage_config.storage_class_mapping.local_disk"]
									"accessMode":   "ReadWriteOnce"
									"size":         parameter.etcd.persistence.size
								}
							}
							"pulsar": {
								"enabled": false
							}
							"kafka": {
								"enabled": false
							}
							"externalS3": {
								"enabled":   true
								"host":      parameter.dependencies.minio.host
								"port":      parameter.dependencies.minio.port
								"accessKey": parameter.dependencies.minio.accessKey
								"secretKey": parameter.dependencies.minio.secretKey
								"useSSL":    false
								if parameter.dependencies.minio.bucketName != _|_ && parameter.dependencies.minio.bucketName != "" {
									"bucketName": parameter.dependencies.minio.bucketName
								}
								if parameter.dependencies.minio.bucketName == _|_ || parameter.dependencies.minio.bucketName == "" {
									"bucketName": parameter.namespace + "-milvus"
								}
								"rootPath":       parameter.dependencies.minio.rootPath
								"useIAM":         false
								"cloudProvider":  "minio"
								"iamEndpoint":    ""
								"region":         ""
								"useVirtualHost": false
							}
							if parameter.clusterMode {
								"externalKafka": {
									"enabled":          true
									"brokerList":       parameter.dependencies.kafka.cluster
									"securityProtocol": "PLAINTEXT"
									"sasl": {
										"mechanisms": "PLAIN"
										"username":   ""
										"password":   ""
									}
								}
							}
						}
					}
				},
			]
		}
	}
	parameter: {
		// +ui:order=0
		// +ui:title=部署模式
		clusterMode: *false | bool
		// +ui:order=1
		// +ui:title=组件依赖
		// +ui:hidden={{rootFormData.clusterMode == false}}
		dependencies: {
			// +ui:description=Kafka
			// +ui:order=1
			kafka: {
				// +ui:description=Kafka 连接地址
				// +ui:order=1
				// +err:options={"required":"请先安装Kafka，或添加Kafka集群配置"}
				cluster: string
			}

			// +ui:description=Minio
			// +ui:order=2
			minio: {
				// +ui:description=Minio 连接地址
				// +ui:order=1
				// +err:options={"required":"请先安装Minio，或添加Minio集群配置"}
				host: string
				// +ui:description=Minio 连接端口
				// +ui:order=2
				// +err:options={"required":"请先安装Minio，或添加Minio集群配置"}
				port: string
				// +ui:description=Minio 用户
				// +ui:order=3
				// +err:options={"required":"请先安装Minio，或添加Minio集群配置"}
				accessKey: string
				// +ui:description=Minio 密码
				// +ui:order=4
				// +err:options={"required":"请先安装Minio，或添加Minio集群配置"}
				secretKey: string
				// +ui:description=Minio 存储桶名称
				// +ui:order=5
				bucketName: *"milvus" | string
				// +ui:description=Minio 路径
				// +ui:order=6
				rootPath: *"/" | string
			}
		}

		// ui:title=ETCD 配置
		// +ui:order=3
		etcd: {
			// +ui:description=资源规格
			// +ui:order=1
			resources: {
				// +ui:description=预留
				// +ui:order=1
				requests: {
					// +ui:description=CPU
					// +ui:order=1
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
					cpu: *"0.5" | string
					// +ui:description=内存
					// +ui:order=2
					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					memory: *"1024Mi" | string
				}
				// +ui:description=限制
				// +ui:order=2
				limits: {
					// +ui:description=CPU
					// +ui:order=1
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
					cpu: *"1.0" | string
					// +ui:description=内存
					// +ui:order=2
					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					memory: *"1024Mi" | string
				}
			}
			// +ui:description=副本数
			// +ui:order=2
			// // +pattern=^([1-9]\d*)$
			// +err:options={"pattern":"请输入正确的副本数"}
			replicas: *3 | int
			// +ui:description=持久化存储配置
			// +ui:order=2
			persistence: {
				// +ui:description=持久卷大小
				// +pattern=^([1-9]\d*)(Ti|Gi|Mi)$
				// +err:options={"pattern":"请输入正确的存储格式，如1Gi"}
				size: *"1Gi" | string
			}
		}

		// ui:title=ETCD 配置
		// +ui:order=4
		// +ui:hidden={{rootFormData.clusterMode == false}}
		proxy: {
			// +ui:description=资源规格
			// +ui:order=1
			resources: {
				// +ui:description=预留
				// +ui:order=1
				requests: {
					// +ui:description=CPU
					// +ui:order=1
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
					cpu: *"0.3" | string
					// +ui:description=内存
					// +ui:order=2
					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					memory: *"1024Mi" | string
				}
				// +ui:description=限制
				// +ui:order=2
				limits: {
					// +ui:description=CPU
					// +ui:order=1
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
					cpu: *"1.0" | string
					// +ui:description=内存
					// +ui:order=2
					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					memory: *"1024Mi" | string
				}
			}
			// +ui:description=副本数
			// +ui:order=2
			// // +pattern=^([1-9]\d*)$
			// +err:options={"pattern":"请输入正确的副本数"}
			replicas: *1 | int
		}

		// ui:title=ETCD 配置
		// +ui:order=5
		// +ui:hidden={{rootFormData.clusterMode == false}}
		rootCoordinator: {
			// +ui:description=资源规格
			// +ui:order=1
			resources: {
				// +ui:description=预留
				// +ui:order=1
				requests: {
					// +ui:description=CPU
					// +ui:order=1
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
					cpu: *"0.3" | string
					// +ui:description=内存
					// +ui:order=2
					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					memory: *"1024Mi" | string
				}
				// +ui:description=限制
				// +ui:order=2
				limits: {
					// +ui:description=CPU
					// +ui:order=1
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
					cpu: *"1.0" | string
					// +ui:description=内存
					// +ui:order=2
					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					memory: *"1024Mi" | string
				}
			}
			// +ui:description=副本数
			// +ui:order=2
			// // +pattern=^([1-9]\d*)$
			// +err:options={"pattern":"请输入正确的副本数"}
			replicas: *1 | int
		}

		// ui:title=ETCD 配置
		// +ui:order=6
		// +ui:hidden={{rootFormData.clusterMode == false}}
		queryCoordinator: {
			// +ui:description=资源规格
			// +ui:order=1
			resources: {
				// +ui:description=预留
				// +ui:order=1
				requests: {
					// +ui:description=CPU
					// +ui:order=1
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
					cpu: *"0.3" | string
					// +ui:description=内存
					// +ui:order=2
					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					memory: *"1024Mi" | string
				}
				// +ui:description=限制
				// +ui:order=2
				limits: {
					// +ui:description=CPU
					// +ui:order=1
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
					cpu: *"1.0" | string
					// +ui:description=内存
					// +ui:order=2
					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					memory: *"1024Mi" | string
				}
			}
			// +ui:description=副本数
			// +ui:order=2
			// // +pattern=^([1-9]\d*)$
			// +err:options={"pattern":"请输入正确的副本数"}
			replicas: *1 | int
		}

		// ui:title=ETCD 配置
		// +ui:order=7
		// +ui:hidden={{rootFormData.clusterMode == false}}
		queryNode: {
			// +ui:description=资源规格
			// +ui:order=1
			resources: {
				// +ui:description=预留
				// +ui:order=1
				requests: {
					// +ui:description=CPU
					// +ui:order=1
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
					cpu: *"0.3" | string
					// +ui:description=内存
					// +ui:order=2
					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					memory: *"1024Mi" | string
				}
				// +ui:description=限制
				// +ui:order=2
				limits: {
					// +ui:description=CPU
					// +ui:order=1
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
					cpu: *"1.0" | string
					// +ui:description=内存
					// +ui:order=2
					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					memory: *"1024Mi" | string
				}
			}
			// +ui:description=副本数
			// +ui:order=2
			// // +pattern=^([1-9]\d*)$
			// +err:options={"pattern":"请输入正确的副本数"}
			replicas: *1 | int
		}

		// ui:title=ETCD 配置
		// +ui:order=8
		// +ui:hidden={{rootFormData.clusterMode == false}}
		indexCoordinator: {
			// +ui:description=资源规格
			// +ui:order=1
			resources: {
				// +ui:description=预留
				// +ui:order=1
				requests: {
					// +ui:description=CPU
					// +ui:order=1
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
					cpu: *"0.3" | string
					// +ui:description=内存
					// +ui:order=2
					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					memory: *"1024Mi" | string
				}
				// +ui:description=限制
				// +ui:order=2
				limits: {
					// +ui:description=CPU
					// +ui:order=1
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
					cpu: *"1.0" | string
					// +ui:description=内存
					// +ui:order=2
					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					memory: *"1024Mi" | string
				}
			}
			// +ui:description=副本数
			// +ui:order=2
			// // +pattern=^([1-9]\d*)$
			// +err:options={"pattern":"请输入正确的副本数"}
			replicas: *1 | int
		}

		// ui:title=ETCD 配置
		// +ui:order=9
		// +ui:hidden={{rootFormData.clusterMode == false}}
		indexNode: {
			// +ui:description=资源规格
			// +ui:order=1
			resources: {
				// +ui:description=预留
				// +ui:order=1
				requests: {
					// +ui:description=CPU
					// +ui:order=1
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
					cpu: *"0.3" | string
					// +ui:description=内存
					// +ui:order=2
					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					memory: *"1024Mi" | string
				}
				// +ui:description=限制
				// +ui:order=2
				limits: {
					// +ui:description=CPU
					// +ui:order=1
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
					cpu: *"1.0" | string
					// +ui:description=内存
					// +ui:order=2
					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					memory: *"1024Mi" | string
				}
			}
			// +ui:description=副本数
			// +ui:order=2
			// // +pattern=^([1-9]\d*)$
			// +err:options={"pattern":"请输入正确的副本数"}
			replicas: *1 | int
		}

		// ui:title=ETCD 配置
		// +ui:order=10
		// +ui:hidden={{rootFormData.clusterMode == false}}
		dataCoordinator: {
			// +ui:description=资源规格
			// +ui:order=1
			resources: {
				// +ui:description=预留
				// +ui:order=1
				requests: {
					// +ui:description=CPU
					// +ui:order=1
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
					cpu: *"0.3" | string
					// +ui:description=内存
					// +ui:order=2
					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					memory: *"1024Mi" | string
				}
				// +ui:description=限制
				// +ui:order=2
				limits: {
					// +ui:description=CPU
					// +ui:order=1
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
					cpu: *"1.0" | string
					// +ui:description=内存
					// +ui:order=2
					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					memory: *"1024Mi" | string
				}
			}
			// +ui:description=副本数
			// +ui:order=2
			// // +pattern=^([1-9]\d*)$
			// +err:options={"pattern":"请输入正确的副本数"}
			replicas: *1 | int
		}

		// ui:title=ETCD 配置
		// +ui:order=11
		// +ui:hidden={{rootFormData.clusterMode == false}}
		dataNode: {
			// +ui:description=资源规格
			// +ui:order=1
			resources: {
				// +ui:description=预留
				// +ui:order=1
				requests: {
					// +ui:description=CPU
					// +ui:order=1
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
					cpu: *"0.3" | string
					// +ui:description=内存
					// +ui:order=2
					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					memory: *"1024Mi" | string
				}
				// +ui:description=限制
				// +ui:order=2
				limits: {
					// +ui:description=CPU
					// +ui:order=1
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
					cpu: *"1.0" | string
					// +ui:description=内存
					// +ui:order=2
					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					memory: *"1024Mi" | string
				}
			}
			// +ui:description=副本数
			// +ui:order=2
			// // +pattern=^([1-9]\d*)$
			// +err:options={"pattern":"请输入正确的副本数"}
			replicas: *1 | int
		}

		// ui:title=Standalone 配置
		// +ui:order=20
		// +ui:hidden={{rootFormData.clusterMode == true}}
		standalone: {
			// +ui:description=资源规格
			// +ui:order=1
			resources: {
				// +ui:description=预留
				// +ui:order=1
				requests: {
					// +ui:description=CPU
					// +ui:order=1
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
					cpu: *"0.5" | string
					// +ui:description=内存
					// +ui:order=2
					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					memory: *"1024Mi" | string
				}
				// +ui:description=限制
				// +ui:order=2
				limits: {
					// +ui:description=CPU
					// +ui:order=1
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
					cpu: *"2.0" | string
					// +ui:description=内存
					// +ui:order=2
					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					memory: *"2048Mi" | string
				}
			}
			// +ui:description=副本数
			// +ui:order=2
			// // +pattern=^([1-9]\d*)$
			// +err:options={"pattern":"请输入正确的副本数"}
			replicas: *1 | int

			// +ui:description=存储大小
			// +ui:order=3
			persistence: {
				// +pattern=^([1-9]\d*)(Ti|Gi|Mi)$
				// +ui:order=1
				// +err:options={"pattern":"请输入正确的存储格式，如1024Mi, 1Gi, 1Ti"}
				size: *"1Gi" | string
			}
		}

		// ui:title=ETCD 配置
		// +ui:order=50
		attu: {
			// +ui:description=资源规格
			// +ui:order=1
			resources: {
				// +ui:description=预留
				// +ui:order=1
				requests: {
					// +ui:description=CPU
					// +ui:order=1
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
					cpu: *"0.3" | string
					// +ui:description=内存
					// +ui:order=2
					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					memory: *"1024Mi" | string
				}
				// +ui:description=限制
				// +ui:order=2
				limits: {
					// +ui:description=CPU
					// +ui:order=1
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
					cpu: *"1.0" | string
					// +ui:description=内存
					// +ui:order=2
					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					memory: *"1024Mi" | string
				}
			}
		}

		// +ui:description=Helm Chart 版本号
		// +ui:order=100
		// +ui:options={"disabled":true}
		chartVersion: *"4.1.33" | string

		// +ui:description=镜像版本
		// +ui:order=101
		// +ui:options={"disabled":true}
		images: {
			// +ui:options={"disabled":true}
			milvus: *"v2.4.4" | string
			// +ui:options={"disabled":true}
			tools: *"v0.1.2" | string
			// +ui:options={"disabled":true}
			attu: *"v2.4.2" | string
		}
	}
}
