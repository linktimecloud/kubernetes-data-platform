import ("strconv")

"spark-history-server": {
	annotations: {}
	labels: {}
	attributes: {
		"dynamicParameterMeta": [
			{
				"name":        "dependencies.hdfsConfigMapName"
				"type":        "ContextSetting"
				"refType":     "hdfs"
				"refKey":      ""
				"description": "hdfs config name"
				"required":    true
			},
		]
		apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "Application"
				type:       "spark-history-server"
			}
		}
	}
	description: "spark-history-server xdefinition"
	type:        "xdefinition"
}

template: {
	output: {
		apiVersion: "core.oam.dev/v1beta1"
		kind:       "Application"
		metadata: {
			"name":      context.name
			"namespace": context.namespace
			"labels": {
				"app":                context.name
				"app.core.bdos/type": "system"
			}
		}
		spec: {
			components: [
				{
					"name": context.name
					"type": "raw"
					"properties": {
						apiVersion: "apps/v1"
						kind:       "Deployment"
						metadata: {
							name: context.name
							annotations: {}
							labels: {
								app: context.name
							}
						}
						spec: {
							replicas: parameter.replicas
							selector: matchLabels: {
								app:                     context.name
								"app.oam.dev/component": context.name
							}
							template: {
								metadata: labels: {
									app:                     context.name
									"app.oam.dev/component": context.name
								}
								spec: {
									containers: [{
										name: context.name
										env: [{
											name:  "HADOOP_CONF_DIR"
											value: "/opt/hadoop/etc/hadoop/"
										}, {
											name:  "SPARK_HISTORY_OPTS"
											value: "-Dspark.history.fs.logDirectory=\(parameter.logDirectory) -Dspark.history.fs.cleaner.enabled=\(strconv.FormatBool(parameter.cleaner.enabled)) -Dspark.history.fs.cleaner.interval=\(parameter.cleaner.interval) -Dspark.history.fs.cleaner.maxAge=\(parameter.cleaner.maxAge) -Dlog4j.configuration=file:///opt/spark/conf/log4j.properties"
										}]
										args: ["/opt/spark/bin/spark-class", "org.apache.spark.deploy.history.HistoryServer"]
										image: "\(context.docker_registry)/\(parameter.image)"
										ports: [{
											containerPort: 18080
											protocol:      "TCP"
										}]
										resources: parameter.resources

										volumeMounts: [{
											name:      "logs"
											mountPath: "/opt/spark/logs/"
										}, {
											name:      "hadoop-config"
											mountPath: "/opt/hadoop/etc/hadoop/"
										}]
									}]

									volumes: [{
										name: "logs"
										emptyDir: {}
									}, {
										name: "hadoop-config"
										configMap: {
											name:        parameter.dependencies.hdfsConfigMapName
											defaultMode: 420
										}
									}]
								}
							}
						}
					}
					"traits": [
						{
							"type": "bdos-security-context"
							"properties": {
								"runAsUser": 0
							}
						},
						{
							"type": "bdos-logtail"
							"properties": {
								"name": "logs"
								"path": "/var/log/\(context.namespace)-\(context.name)"
							}
						},
						{
							"type": "bdos-ingress"
							"properties": {
								"rules": [
									{
										"host": context["name"] + "-" + context["namespace"] + "." + context["ingress.root_domain"]
										"paths": [
											{
												"path":        "/"
												"servicePort": 18080
											},
										]
									},
								]
								"tls": [
									{
										"hosts": [
											context["name"] + "-" + context["namespace"] + "." + context["ingress.root_domain"],
										]
										"tlsSecretName": context["ingress.tls_secret_name"]
									},
								]
							}
						},
					]
				},
				{
					"name": context.name + "-svc"
					"type": "raw"
					"properties": {
						apiVersion: "v1"
						kind:       "Service"
						metadata: {
							name: context.name + "-svc"
							labels: {
								"app": context.name
							}
						}
						spec: {
							type: "ClusterIP"
							selector: {
								"app": context.name
							}
							ports: [
								{
									name:       "port-tcp-18080"
									targetPort: 18080
									port:       18080
									protocol:   "TCP"
								},
							]
						}
					}
				},
			]
		}
	}
	parameter: {
		// +ui:title=组件依赖
		// +ui:order=1
		dependencies: {
			// +ui:description=HDFS 上下文
			// +ui:order=2
			// +err:options={"required":"请先安装 HDFS"}
			hdfsConfigMapName: string
		}
		// +ui:description=副本数
		// +ui:order=2
		// +minimum=1
		replicas: *1 | int
		// +ui:description=资源规格
		// +ui:order=3
		resources: {
			// +ui:description=预留
			// +ui:order=1
			requests: {
				// +ui:description=CPU
				// +ui:order=1
				// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
				// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
				cpu: string
				// +ui:description=内存
				// +ui:order=2
				// +pattern=^[1-9]\d*(Mi|Gi)$
				// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
				memory: string
			}
			// +ui:description=限制
			// +ui:order=2
			limits: {
				// +ui:description=CPU
				// +ui:order=1
				// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
				// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
				cpu: string
				// +ui:description=内存
				// +ui:order=2
				// +pattern=^[1-9]\d*(Mi|Gi)$
				// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
				memory: string
			}
		}
		// +ui:description=Spark 日志路径
		// +ui:order=4
		logDirectory: *"hdfs:///historyservice" | string
		// +ui:description=自动清理 Spark 日志
		// +ui:order=5
		cleaner: {
			// +ui:description=开启自动清理
			// +ui:order=1
			enabled: *true | bool
			// +ui:description=清理周期
			// +ui:order=2
			// +ui:hidden={{parentFormData.enabled===false}}
			// +pattern=^([0-9]+)(s|m|h|d)$
			// +err:options={"pattern":"请输入正确的时间格式，如1h, 1d"}
			interval: *"1d" | string
			// +ui:description=最大保留时间
			// +ui:order=3
			// +ui:hidden={{parentFormData.enabled===false}}
			// +pattern=^([0-9]+)(s|m|h|d)$
			// +err:options={"pattern":"请输入正确的时间格式，如1h, 1d"}
			maxAge: *"30d" | string
		}
		// +ui:description=镜像版本
		// +ui:order=100
		// +ui:options={"disabled":true}
		image: string
	}
}
