jupyterlab: {
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
			{
				"name":        "dependencies.hiveConfigMapName"
				"type":        "ContextSetting"
				"refType":     "hive-metastore"
				"refKey":      ""
				"description": "hive metastore config name"
				"required":    true
			},
		]
		apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "Application"
				type:       "jupyterlab"
			}
		}
	}
	description: "jupyterlab"
	type:        "xdefinition"
}

template: {
	_imageRegistry: *"" | string
	if context.docker_registry != _|_ && len(context.docker_registry) > 0 {
		_imageRegistry: context.docker_registry + "/"
	}

	output: {
		"apiVersion": "core.oam.dev/v1beta1"
		"kind":       "Application"
		"metadata": {
			"name":      context["name"]
			"namespace": context["namespace"]
			"labels": {
				"app":                context["name"]
				"app.core.bdos/type": "system"
			}
			"annotations": {
				"app.core.bdos/catalog":      "jupyterlab"
				"reloader.stakater.com/auto": "true"
			}
		}
		"spec": {
			"components": [
				{
					"name": "jupyterlab"
					"type": "k8s-objects"
					"properties": {
						"objects": [
							{
								apiVersion: "apps/v1"
								kind:       "Deployment"
								metadata: {
									annotations: {
										"app.core.bdos/catalog": "jupyterlab"
									}
									labels: {
										app:                  context.name
										"app.core.bdos/type": "system"
									}
									name: context.name
									if parameter.namespace != _|_ {
										namespace: parameter.namespace
									}
								}
								spec: {
									if parameter["replicas"] != _|_ {
										replicas: parameter.replicas
									}
									selector: matchLabels: {
										app:                     context.name
										"app.oam.dev/component": context.name
									}
									template: {
										metadata: {
											labels: {
												app:                     context.name
												"app.oam.dev/component": context.name
											}
										}
										spec: {
											containers: [{
												name: "jupyterlab"
												env: [
													{
														"name":  "CHOWN_HOME"
														"value": "yes"
													},
													{
														"name":  "NOTEBOOK_ARGS"
														"value": "--LabApp.token=''"
													},
												]

												image:           _imageRegistry + parameter.image
												imagePullPolicy: "IfNotPresent"
												if parameter.command != _|_ {
													command: parameter.command
												}
												if parameter["args"] != _|_ {
													args: parameter.args
												}
												livenessProbe: {
													initialDelaySeconds: 20
                          periodSeconds: 20
                          failureThreshold: 3
                          timeoutSeconds: 10
                          tcpSocket: {
                            port: 8888
                          }
												}
												readinessProbe: {
													initialDelaySeconds: 20
                          periodSeconds: 20
                          failureThreshold: 3
                          timeoutSeconds: 10
                          tcpSocket: {
                            port: 8888
                          }
												}
												if parameter.hdfsEnabled {
													volumeMounts: [
														{
															mountPath: "/usr/local/spark/conf/core-site.xml"
															name:      "hdfs-conf"
															subPath: "core-site.xml"
														},
														{
															mountPath: "/usr/local/spark/conf/hdfs-site.xml"
															name:      "hdfs-conf"
															subPath: "hdfs-site.xml"
														},
														{
															mountPath: "/usr/local/spark/conf/hive-site.xml"
															name:      "hive-conf"
															subPath: "hive-site.xml"
														},
													]
												}
											}]
											restartPolicy: "Always"
											if parameter["imagePullSecrets"] != _|_ {
												imagePullSecrets: [
													context["K8S_IMAGE_PULL_SECRETS_NAME"],
												]
											}
											serviceAccountName: context.name
											if parameter.hdfsEnabled {
												volumes: [
													{
														name: "hdfs-conf"
														configMap: {
															name: parameter.dependencies.hdfsConfigMapName
														}
													},
													{
														name: "hive-conf"
														configMap: {
															name: parameter.dependencies.hiveConfigMapName
														}
													},
												]
											}
										}
									}
								}
							}
						]
					}
					"traits": [
						{
							"type": "bdos-pvc"
							"properties": {
								"namespace": context.namespace
								"claimName": context.name + "-pvc"
								"accessModes": [
									"ReadWriteOnce",
								]
								"resources": {
									"requests": {
										"storage": parameter.storage.size
									}
								}
								"storageClassName": context["storage_config.storage_class_mapping.local_disk"]
								"volumesToMount": [
									{
										"name":      "jupyterlab-data"
										"mountPath": "/home/root"
									},
								]
							}
						},
						{
							"type": "bdos-service-account"
							"properties": {
								"name": context["name"]
							}
						},
						{
							"type": "bdos-expose"
							"properties": {
								serviceName: context.name + "-svc"
								"stickySession": true
								"ports": [
									{
										"containerPort": 8888
										"protocol":      "TCP"
									},
									{
										"containerPort": 4040
										"protocol":      "TCP"
									},
								]
							}
						},
						{
							"type":          "bdos-ingress"
							"properties": {
								ingressName: context.name + "-ingress"
								"rules": [
									{
										"host": "jupyterlab-" + context.namespace + "." + context["ingress.root_domain"],
										"paths": [
											{
												"path":        "/"
												"serviceName": context.name + "-svc"
												"servicePort": 8888
											},
										]
									},
								]
								"tls": [
									{
										"hosts": [
											"jupyterlab-" + context.namespace + "." + context["ingress.root_domain"],
										]
										"tlsSecretName": context["ingress.tls_secret_name"]
									},
								]
							}
						},
					]
				},
			]
			"policies": [
				{
					"name": "garbage-collect"
					"type": "garbage-collect"
					"properties": {
						"rules": [
							{
								"selector": {
									"traitTypes": [
										"bdos-pvc",
									]
								}
								"strategy": "never"
							},
						]
					}
				},
				{
					name: "take-over"
					type: "take-over"
					properties: {
						rules: [
							{
								selector: {
									traitTypes: [
										"bdos-pvc",
									]
								}
							},
						]
					}
				},
			]
		}
	}

	outputs: {}

	parameter: {

		// +ui:order=1
		// +ui:description=HDFS 配置
		hdfsEnabled: *false | bool

		// +ui:order=2
		// +ui:description=组件依赖
		// +ui:title=组件依赖
		// +ui:hidden={{rootFormData.hdfsEnabled == false}}
		dependencies: {
			// +ui:description=HDFS 上下文
			// +ui:order=1
			// +err:options={"required":"请先安装 HDFS"}
			hdfsConfigMapName: string
			// +ui:description=Hive Metastore 上下文
			// +ui:order=3
			// +err:options={"required":"请先安装 Hive Metastore"}
			hiveConfigMapName: string
		}
		// +ui:order=2
		// +minimum=1
		// +ui:description=副本数
		replicas: *1 | int
		// +ui:order=3
		// +ui:description=资源规格
		resources: {
			// +ui:order=1
			// +ui:description=预留
			requests: {
				// +ui:order=1
				// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
				// +err:options={"pattern":"请输入正确的CPU格式，如0.25，250m"}
				// +ui:description=CPU
				cpu: *"0.5" | string
				// +ui:order=2
				// +pattern=^[1-9]\d*(Mi|Gi)$
				// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
				// +ui:description=内存
				memory: *"2Gi" | string
			}
			// +ui:order=2
			// +ui:description=限制
			limits: {
				// +ui:order=1
				// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
				// +err:options={"pattern":"请输入正确的CPU格式，如0.25，250m"}
				// +ui:description=CPU
				cpu: *"2" | string
				// +ui:order=2
				// +pattern=^[1-9]\d*(Mi|Gi)$
				// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
				// +ui:description=内存
				memory: *"2Gi" | string
			}
		}

		// +ui:order=4
		// +ui:description=存储配置
		storage: {
			// +ui:order=1
			// +ui:description=存储大小
			// +pattern=^([1-9]\d*)(Ti|Gi|Mi)$
			size: *"10Gi" | string
		}
		// +ui:order=100
		// +ui:options={"disabled":true}
		// +ui:description=镜像版本
		image: *"jupyter/pyspark-notebook:spark-3.3.0" | string
	}
}
