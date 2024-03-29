flink: {
	annotations: {}
	labels: {}
	attributes: {
		dynamicParameterMeta: [
			{
				name:        "ha.zookeeper.quorum"
				type:        "ContextSetting"
				refType:     "zookeeper"
				refKey:      "hostname"
				description: "zookeeper url"
				required:    false
			},
			{
				name:        "ha.zookeeper.port"
				type:        "ContextSetting"
				refType:     "zookeeper"
				refKey:      "port"
				description: "zookeeper port"
				required:    false
			},
			{
				name:        "ha.storage.hdfs.configName"
				type:        "ContextSetting"
				refType:     "hdfs"
				refKey:      ""
				description: "flink ha hdfs config name"
				required:    false
			},
			{
				name:        "hive.hmsConfigName"
				type:        "ContextSetting"
				refType:     "hive-metastore"
				refKey:      ""
				description: "hive hms config name"
				required:    false
			},
			{
				name:        "hive.hdfsConfigName"
				type:        "ContextSetting"
				refType:     "hdfs"
				refKey:      ""
				description: "hive hdfs config name"
				required:    false
			},
		]
		apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "Application"
				type:       "flink"
			}
		}
	}
	description: "flink"
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
				{name: context.name
					type: "raw"
					properties: {
						// https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-release-1.7/docs/custom-resource/reference/
						kind:       "FlinkDeployment"
						apiVersion: "flink.apache.org/v1beta1"
						metadata: {
							name:      context.name
							namespace: context.namespace
						}
						spec: {
							flinkConfiguration: {

								if parameter.metrics.enable && "\(parameter.flinkVersion)" == "v1_17" {
									"metrics.reporter.prom.factory.class": "org.apache.flink.metrics.prometheus.PrometheusReporterFactory"
									"metrics.reporter.prom.port":          "9249"
								}
								if parameter.ha.enable && "\(parameter.ha.type)" == "zookeeper" {
									"high-availability.type":                "zookeeper"
									"high-availability.zookeeper.quorum":    parameter.ha.zookeeper.quorum + ":" + parameter.ha.zookeeper.port
									"high-availability.zookeeper.path.root": "/flink/" + context.namespace + "/" + context.name
								}
								if parameter.ha.enable && "\(parameter.ha.type)" == "kubernetes" {
									"high-availability.type":       "kubernetes"
									// Operator 禁止更新下面的key: 
									// - "high-availability.cluster-id"
									// - "kubernetes.cluster-id":
								}
								if parameter.ha.enable && "\(parameter.ha.storage.type)" == "hdfs" {
									"high-availability.storageDir":           "hdfs:///flink/recovery/" + context.namespace
									"state.backend":                          "filesystem"
									"state.checkpoints.dir":                  "hdfs:///flink/checkpoints/" + context.namespace
									"state.savepoints.dir":                   "hdfs:///flink/savepoints/" + context.namespace
									"kubernetes.hadoop.conf.config-map.name": parameter.ha.storage.hdfs.configName
								}
								if parameter.ha.enable && "\(parameter.ha.storage.type)" == "s3" {
									"high-availability.storageDir": "s3://" + parameter.ha.storage.s3.bucket + "/recovery/" + context.namespace
									"state.backend":                "filesystem"
									"state.checkpoints.dir":        "s3://" + parameter.ha.storage.s3.bucket + "/checkpoints/" + context.namespace
									"state.savepoints.dir":         "s3://" + parameter.ha.storage.s3.bucket + "/savepoints/" + context.namespace
									"s3.endpoint":                  parameter.ha.storage.s3.endpoint
									"s3.access.key":                parameter.ha.storage.s3.accesskey
									"s3.secret.key":                parameter.ha.storage.s3.secretkey
									"s3.path.style.access":         "true"
								}
								if parameter.extraFlinkConfiguration != _|_ {
									for k, v in parameter.extraFlinkConfiguration {
										"\(k)": v
									}
								}
							}
							flinkVersion: parameter.flinkVersion
							image:        context["docker_registry"] + "/" + parameter.flink17Image

							serviceAccount: parameter.serviceAccount
							jobManager: {
								resource: {
									cpu:    parameter.jobManager.resources.cpu
									memory: parameter.jobManager.resources.memory
								}
							}
							taskManager: {
								resource: {
									cpu:    parameter.taskManager.resources.cpu
									memory: parameter.taskManager.resources.memory
								}
							}
							podTemplate: spec: {
								affinity: {}
								_hiveVolumes: [...]
								if parameter.hive.enable {
									_hiveVolumes: [
										{
											name: "flink-hms-config"
											configMap: {
												name: parameter.hive.hmsConfigName
											}
										}, {
											name: "flink-hms-hdfs-config"
											configMap: {
												name: parameter.hive.hdfsConfigName
											}
										},
									]
								}
								volumes: [] + _hiveVolumes
								containers: [
									{
										name: "flink-main-container"
										if parameter.metrics.enable {
											ports: [
												{
													name:          "metrics"
													containerPort: 9249
													protocol:      "TCP"
												},
											]
										}
										_hiveVolumeMounts: [...]
										if parameter.hive.enable {
											_hiveVolumeMounts: [
												{
													"name":      "flink-hms-config"
													"mountPath": "/opt/hive-conf"
												}, {
													"name":      "flink-hms-hdfs-config"
													"mountPath": "/opt/hdfs-conf"
												},
											]
										}
										volumeMounts: [] + _hiveVolumeMounts
									},
								]
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
										port:     9249
										path:     "/"
										portName: "metrics"
									},
								]
								matchLabels: {
									app: context.name
								}
							}
						},
						{
							type: "bdos-ingress"
							properties: {
								rules: [
									{
										host: context["name"] + "-" + context["namespace"] + "." + context["ingress.root_domain"]
										paths: [
											{
												path:        "/"
												servicePort: 8081
												serviceName: context.name + "-rest"
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
						},
					]
				},
				{
					name: "flink-service-account"
					properties: {
						apiVersion: "v1"
						kind:       "ServiceAccount"
						metadata: {
							name:      "flink"
							namespace: context.namespace
						}
					}
					type: "raw"
				},
				{
					name: "flink-role"
					properties: {
						rules: [
							{
								apiGroups: [
									"*",
								]
								resources: [
									"pods",
									"services",
									"configmaps",
								]
								verbs: [
									"get",
									"watch",
									"list",
									"create",
									"update",
									"patch",
									"delete",
								]
							},
							{
								apiGroups: [
									"apps",
								]
								resources: [
									"deployments",
									"deployments/finalizers",
								]
								verbs: [
									"*",
								]
							},
						]
					}
					type: "bdos-role"
				},
				{
					name: "flink-rolebinding"
					properties: {
						roleName: "flink-role"
						serviceAccounts: [
							{
								namespace:          context.namespace
								serviceAccountName: "flink"
							},
						]
					}
					type: "bdos-role-binding"
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
										"flink-role",
									]
								}
							},
							{
								selector: {
									componentNames: [
										"flink-rolebinding",
									]
								}
							},
							{
								selector: {
									componentNames: [
										"flink-service-account",
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
		// +ui:description=Flink版本
		// +ui:order=1
		// +ui:options={"disabled": true}
		flinkVersion: *"v1_17" | string

		// +ui:title=image
		// +ui:description=镜像
		// +ui:order=2
		// +ui:hidden={{rootFormData.flinkVersion != "v1_17"}}
		// +ui:options={"disabled": true}
		flink17Image: *"flink/flink:v1.0.0-1.17.1_scala_2.12" | string

		// +ui:description=job manager资源配置
		// +ui:order=3
		jobManager: {
			// +ui:description=资源规格 
			resources: {
				// pattern: ^[0-9]+(\.[0-9])?$
				// +err:options={"pattern":"请输入正确的cpu资源配置, 如0.1"}
				// +ui:description=CPU
				cpu: *0.1 | float

				// pattern: ^[0-9]+[m|g]$
				// +err:options={"pattern":"请输入正确的内存资源配置, 如2048m, 2g"}
				// +ui:description=内存
				memory: *"2048m" | string
			}
		}

		// +ui:description=task manager资源配置
		// +ui:order=4
		taskManager: {
			// +ui:description=资源规格
			resources: {
				// pattern: ^[0-9]+(\.[0-9])?$
				// +err:options={"pattern":"请输入正确的cpu资源配置, 如0.1"}
				// +ui:description=CPU
				cpu: *0.5 | float

				// pattern: ^[0-9]+[m|g]$
				// +err:options={"pattern":"请输入正确的内存资源配置, 如2048m, 2g"}
				// +ui:description=内存
				memory: *"2048m" | string
			}
		}

		// +ui:title=高可用配置
		// +ui:order=5
		ha: {
			// +ui:description=是否启用高可用, 生产环境建议启用
			// +ui:order=1
			enable: *true | bool

			// +ui:description=选择高可用类型，支持kubernetes和zookeeper
			// +ui:hidden={{rootFormData.ha.enable == false}}
			// +ui:order=2
			type: "kubernetes" | "zookeeper"

			// +ui:description=使用zookeeper作为高可用
			// +ui:hidden={{rootFormData.ha.type != "zookeeper"}}
			// +ui:order=3
			zookeeper: {

				// +ui:description=Zookeeper hostname
				// +err:options={"required":"请先安装zookeeper"}
				quorum: string

				// +ui:description=端口
				// +err:options={"required":"请先安装zookeeper"}
				port: string
			}

			// +ui:description=配置高可用元数据的存储
			// +ui:hidden={{rootFormData.ha.enable == false}}
			// +ui:order=3
			storage: {
				// +ui:title=存储类型
				// +ui:description=选择高可用元数据的存储位置，支持hdfs和s3
				// +ui:order=1
				type: "hdfs" | "s3"

				// +ui:description=配置hdfs作为高可用元数据的存储
				// +ui:hidden={{rootFormData.ha.storage.type != "hdfs"}}
				// +ui:order=2
				hdfs: {
					// +ui:description=配置hdfs依赖
					// +ui:hidden={{rootFormData.ha.storage.type != "hdfs"}}
					// +err:options={"required":"存储依赖hdfs, 请先安装hdfs"}
					configName: string
				}

				// +ui:description=配置S3作为高可用元数据的存储
				// +ui:hidden={{rootFormData.ha.storage.type != "s3"}}
				// +ui:order=3
				s3: {
					// +ui:options={"description":"请输入S3 endpoint, 如 http://minio:9000"}
					// +ui:order=1
					endpoint: string

					// +ui:options={"description":"请输入S3 bucket, 如 kdp-flink-checkpoint, 请确保bucket已创建"}
					// +ui:order=2
					bucket: string

					// +ui:options={"description":"请输入S3 accesskey, 如 minio用户名, 请确保用户有bucket的读写权限"}
					// +ui:order=3
					accesskey: string

					// +ui:options={"description":"请输入S3 secretkey, 如 minio用户密码"}
					// +ui:order=4
					secretkey: string
				}

			}

		}

		// +ui:title=指标配置
		// +ui:description=开启指标采集，供grafana展示
		// +ui:order=5
		// +ui:hidden=true
		metrics: {
			enable: *true | bool
		}

		// +ui:title=ServiceAccount配置
		// +ui:description=配置flink的k8s serviceAccount
		// +ui:order=6
		// +ui:hidden=true
		serviceAccount: *"flink" | string

		// +ui:title=Flink on Hive配置
		// +ui:order=8
		hive: {
			// +ui:description=是否启用Flink on Hive
			// +ui:order=1
			enable: *false | bool

			// +minLength=3
			// +ui:description=配置Hive Metastore依赖
			// +ui:hidden={{rootFormData.hive.enable == false}}
			// +err:options={"required":"请先安装hive-metastore"}
			hmsConfigName: string

			// +ui:description=配置HDFS依赖
			// +ui:hidden={{rootFormData.hive.enable == false}}
			// +err:options={"required":"请先安装hdfs"}
			hdfsConfigName: string
		}

		// +ui:description=配置conf/flink-conf.yaml, 请参考官方文档：https://nightlies.apache.org/flink/flink-docs-master/docs/deployment/config/
		// +ui:order=9
		extraFlinkConfiguration?: {...}
	}

}
