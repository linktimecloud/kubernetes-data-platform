import "strings"

"juicefs": {
	annotations: {}
	labels: {}
	attributes: {
		dynamicParameterMeta: [
			{
				name:        "mysql.mysqlSetting"
				type:        "ContextSetting"
				refType:     "mysql"
				refKey:      ""
				description: "mysql setting name"
				required:    true
			},
			{
				name:        "mysql.mysqlSecret"
				type:        "ContextSecret"
				refType:     "mysql"
				refKey:      ""
				description: "mysql secret name"
				required:    true
			},
			{
				name:        "minio.contextSetting"
				type:        "ContextSetting"
				refType:     "minio"
				refKey:      ""
				description: ""
				required:    true
			},
			{
				name:        "minio.contextSecret"
				type:        "ContextSecret"
				refType:     "minio"
				refKey:      ""
				description: ""
				required:    true
			},

		]
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
							replicaCount: parameter.replicaCount
							secret: {
								name:    "jfs-volume"
								storage: "minio"
								// Do not remove the empty string, otherwise the chart will not work
								accessKey: " "
								secretKey: " "
								bucket:    " "
							}
							options: "--multi-buckets"
							envs: [
								{
									name: "MYSQL_PASSWORD"
									valueFrom: {
										secretKeyRef: {
											key:  "MYSQL_PASSWORD"
											name: "\(parameter.mysql.mysqlSecret)"
										}
									}
								},
								{
									name: "MYSQL_USER"
									valueFrom: {
										secretKeyRef: {
											key:  "MYSQL_USER"
											name: "\(parameter.mysql.mysqlSecret)"
										}
									}
								},
								{
									name:  "DATABASE"
									value: _databaseName
								},
								{
									name: "MYSQL_HOST"
									valueFrom: configMapKeyRef: {
										name: "\(parameter.mysql.mysqlSetting)"
										key:  "MYSQL_HOST"
									}
								},
								{
									name: "MYSQL_PORT"
									valueFrom: configMapKeyRef: {
										name: "\(parameter.mysql.mysqlSetting)"
										key:  "MYSQL_PORT"
									}
								},
								{
									name:  "METAURL"
									value: "mysql://$(MYSQL_USER):$(MYSQL_PASSWORD)@($(MYSQL_HOST):$(MYSQL_PORT))/$(DATABASE)"
								},
								{
									name: "MINIO_ROOT_PASSWORD"
									valueFrom: {
										secretKeyRef: {
											key:  "MINIO_ROOT_PASSWORD"
											name: "\(parameter.minio.contextSecret)"
										}
									}
								},
								{
									name: "MINIO_ROOT_USER"
									valueFrom: {
										secretKeyRef: {
											key:  "MINIO_ROOT_USER"
											name: "\(parameter.minio.contextSecret)"
										}
									}
								},
							]
							initEnvs: [
								{
									name: "MYSQL_PASSWORD"
									valueFrom: {
										secretKeyRef: {
											key:  "MYSQL_PASSWORD"
											name: "\(parameter.mysql.mysqlSecret)"
										}
									}
								},
								{
									name: "MYSQL_USER"
									valueFrom: {
										secretKeyRef: {
											key:  "MYSQL_USER"
											name: "\(parameter.mysql.mysqlSecret)"
										}
									}

								},
								{
									name:  "DATABASE"
									value: _databaseName
								},
								{
									name: "MYSQL_HOST"
									valueFrom: configMapKeyRef: {
										name: "\(parameter.mysql.mysqlSetting)"
										key:  "MYSQL_HOST"
									}
								},
								{
									name: "MYSQL_PORT"
									valueFrom: configMapKeyRef: {
										name: "\(parameter.mysql.mysqlSetting)"
										key:  "MYSQL_PORT"
									}
								},
								{
									name:  "metaurl"
									value: "mysql://$(MYSQL_USER):$(MYSQL_PASSWORD)@($(MYSQL_HOST):$(MYSQL_PORT))/$(DATABASE)"
								},
								{
									name: "secretkey"
									valueFrom: {
										secretKeyRef: {
											key:  "MINIO_ROOT_PASSWORD"
											name: "\(parameter.minio.contextSecret)"
										}
									}
								},
								{
									name: "accesskey"
									valueFrom: {
										secretKeyRef: {
											key:  "MINIO_ROOT_USER"
											name: "\(parameter.minio.contextSecret)"
										}
									}
								},
								{
									name: "bucketHost"
									valueFrom: {
										configMapKeyRef: {
											key:  "host"
											name: "\(parameter.minio.contextSetting)"
										}
									}
								},
								{
									name:  "bucket"
									value: "http://$(bucketHost)/juicefs"
								},

							]

							if parameter.resources != _|_ {
								resources: parameter.resources
							}
							if parameter.affinity != _|_ {
								affinity: parameter.affinity
							}
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

				{
					name: context["name"] + "-create-database-job"
					type: "k8s-objects"
					properties: {
						objects: [{
							apiVersion: "batch/v1"
							kind:       "Job"
							metadata: name: "create-mysql-database"
							labels: {
								app:                  context.name
								"app.core.bdos/type": "system"
							}
							spec: template: spec: {
								containers: [{
									name:  "create-mysql-database"
									image: _imageRegistry + "bitnami/mysql:8.0.22"
									env: [
										{
											name: "PASSWORD"
											valueFrom: {
												secretKeyRef: {
													key:  "MYSQL_PASSWORD"
													name: "\(parameter.mysql.mysqlSecret)"
												}
											}
										},
										{
											name: "USER"
											valueFrom: {
												secretKeyRef: {
													key:  "MYSQL_USER"
													name: "\(parameter.mysql.mysqlSecret)"
												}
											}
										},
										{
											name:  "DATABASE"
											value: _databaseName
										},
										{
											name: "MYSQL_HOST"
											valueFrom: configMapKeyRef: {
												name: "\(parameter.mysql.mysqlSetting)"
												key:  "MYSQL_HOST"
											}
										},
										{
											name: "MYSQL_PORT"
											valueFrom: configMapKeyRef: {
												name: "\(parameter.mysql.mysqlSetting)"
												key:  "MYSQL_PORT"
											}
										},
									]
									command: [
										"sh",
										"-c",
										"mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $USER -p$PASSWORD -e \"CREATE DATABASE IF NOT EXISTS $DATABASE CHARACTER SET utf8 COLLATE utf8_general_ci; CREATE DATABASE IF NOT EXISTS ${DATABASE}_examples CHARACTER SET utf8 COLLATE utf8_general_ci;\"",
									]
								}]
								restartPolicy: "Never"
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
				{
					type: "apply-once"
					name: "apply-once-res"
					properties: rules: [
						{
							selector: resourceTypes: ["Job"]
							strategy: {
								path: ["*"]
							}
						},
					]
				},
			]
		}
	}

	parameter: {
		// +ui:description=数据库依赖
		// +ui:order=1
		mysql: {
			// +ui:description=数据库连接信息
			// +err:options={"required":"请先安装mysql"}
			mysqlSetting: string

			// +ui:description=数据库认证信息
			// +err:options={"required":"请先安装mysql"}
			mysqlSecret: string
		}

		minio: {
			contextSetting: string
			contextSecret:  string
		}

		// +minimum=1
		// +ui:description=副本数
		// +ui:order=2
		replicaCount: *1 | int

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

		// +ui:description=配置kubernetes亲和性和反亲和性，请根据实际情况调整
		// +ui:order=6
		affinity?: {}

	}
}
