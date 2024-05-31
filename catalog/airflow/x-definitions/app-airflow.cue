import "strings"

airflow: {
	annotations: {}
	labels: {}
	attributes: {
		dynamicParameterMeta: [
			{
				name:        "dependencies.mysql.mysqlSetting"
				type:        "ContextSetting"
				refType:     "mysql"
				refKey:      ""
				description: "mysql setting name"
				required:    true
			},
			{
				name:        "dependencies.mysql.mysqlSecret"
				type:        "ContextSecret"
				refType:     "mysql"
				refKey:      ""
				description: "mysql secret name"
				required:    true
			},
		]
	}
	description: "airflow xdefinition"
	type:        "xdefinition"
}

template: {
	_databaseName:  "\(strings.Replace(context.namespace+"_airflow", "-", "_", -1))"
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
						chart:           "airflow"
						version:         parameter.chartVersion
						url:             context["helm_repo_url"]
						repoType:        "oci"
						releaseName:     context.name
						targetNamespace: context.namespace
						values: {
							defaultAirflowRepository: _imageRegistry + "apache/airflow"
							defaultAirflowTag:        parameter.images.airflow.tag
							executor:                 "KubernetesExecutor"
							dags: {
								gitSync: {
									enabled: true
									repo:    parameter.dags.gitSync.repo
									branch:  parameter.dags.gitSync.branch
									rev:     parameter.dags.gitSync.rev
									subPath: parameter.dags.gitSync.subPath
								}
							}
							config: {
								core: {
									"default_timezone": "Asia/Shanghai"
								}
								webserver: {
									"default_ui_timezone": "Asia/Shanghai"
								}
								scheduler: {
									"dag_dir_list_interval": 60
								}
							}
							extraEnvFrom: """
							   - secretRef:
							       name: '\(parameter.dependencies.mysql.mysqlSecret)'
							   - configMapRef:
							       name: '\(parameter.dependencies.mysql.mysqlSetting)'
							"""
							data: {
								metadataConnection: {
									protocol: "mysql"
									db:       _databaseName
									sslmode:  "disable"
								}
							}
							postgresql: {
								enabled: false
							}
							migrateDatabaseJob: {
								useHelmHooks: false
							}
							webserverSecretKey: "feab0e05d989b76acb325a8b35e596c9"
							webserver: {
								replicas: parameter.webserver.replicas
								resources: {
									limits: {
										cpu:    parameter.webserver.resources.limits.cpu
										memory: parameter.webserver.resources.limits.memory
									}
									requests: {
										cpu:    parameter.webserver.resources.requests.cpu
										memory: parameter.webserver.resources.requests.memory
									}
								}
								startupProbe: {
									timeoutSeconds:   20
									failureThreshold: 20
									periodSeconds:    10
								}
							}
							scheduler: {
								replicas: parameter.scheduler.replicas
								resources: {
									limits: {
										cpu:    parameter.scheduler.resources.limits.cpu
										memory: parameter.scheduler.resources.limits.memory
									}
									requests: {
										cpu:    parameter.scheduler.resources.requests.cpu
										memory: parameter.scheduler.resources.requests.memory
									}
								}
								startupProbe: {
									timeoutSeconds:   20
									failureThreshold: 20
									periodSeconds:    10
								}
								extraInitContainers: [
									{
										name:  "create-mysql-database"
										image: _imageRegistry + "bitnami/mysql:8.0.22"
										env: [
											{
												name: "PASSWORD"
												valueFrom: {
													secretKeyRef: {
														key:  "MYSQL_PASSWORD"
														name: "\(parameter.dependencies.mysql.mysqlSecret)"
													}
												}
											},
											{
												name: "USER"
												valueFrom: {
													secretKeyRef: {
														key:  "MYSQL_USER"
														name: "\(parameter.dependencies.mysql.mysqlSecret)"
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
													name: "\(parameter.dependencies.mysql.mysqlSetting)"
													key:  "MYSQL_HOST"
												}
											},
											{
												name: "MYSQL_PORT"
												valueFrom: configMapKeyRef: {
													name: "\(parameter.dependencies.mysql.mysqlSetting)"
													key:  "MYSQL_PORT"
												}
											},
										]
										command: [
											"sh",
											"-c",
											"mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $USER -p$PASSWORD -e \"CREATE DATABASE IF NOT EXISTS $DATABASE CHARACTER SET utf8mb4;\"",
										]
									},
								]
							}
							workers: {
								replicas:                      parameter.workers.replicas
								terminationGracePeriodSeconds: 60
								resources: {
									limits: {
										cpu:    parameter.workers.resources.limits.cpu
										memory: parameter.workers.resources.limits.memory
									}
									requests: {
										cpu:    parameter.workers.resources.requests.cpu
										memory: parameter.workers.resources.requests.memory
									}
								}
								persistence: {
									enabled: false
								}
							}
							ingress: {
								web: {
									enabled: true
									hosts: [
										{
											name: "airflow-web-" + context.namespace + "." + context["ingress.root_domain"]
										},
									]
								}
							}
							images: {
								statsd: {
									repository: _imageRegistry + "prometheus/statsd-exporter"
								}
								gitSync: {
									repository: _imageRegistry + "git-sync/git-sync"
									tag:        "v4.2.3"
								}

							}
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
			// +ui:order=1
			// +ui:description=MySQL 配置
			mysql: {
				// +ui:order=1
				// +ui:description=数据库连接信息
				// +err:options={"required":"请先安装Mysql"}
				mysqlSetting: string
				// +ui:order=2
				// +ui:description=数据库认证信息
				// +err:options={"required":"请先安装Mysql"}
				mysqlSecret: string
			}
		}

		// ui:title=DAG 配置
		// +ui:order=2
		dags: {
			// +ui:description=git 同步配置 (必须配置)
			gitSync: {
				// +ui:description=git 仓库地址
				// +ui:order=1
				repo: *"https://gitee.com/linktime-cloud/example-datasets.git" | string
				// +ui:description=git 仓库分支
				// +ui:order=2
				branch: *"airflow" | string
				// +ui:description=git 仓库提交 ID 
				// +ui:order=3
				rev: *"HEAD" | string
				// +ui:description= DAG 代码目录 (根目录请使用空字符串)
				// +ui:order=4
				subPath: *"dags" | string
			}
		}

		// +ui:title=Webserver
		// +ui:order=3
		webserver: {
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
					cpu: *"0.1" | string
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
					memory: *"2048Mi" | string
				}
			}
			// +ui:description=副本数
			// +ui:order=2
			// // +pattern=^([1-9]\d*)$
			// +err:options={"pattern":"请输入正确的副本数"}
			replicas: *1 | int
		}
		// +ui:title=Scheduler
		// +ui:order=4
		scheduler: {
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
					cpu: *"0.1" | string
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
					memory: *"2048Mi" | string
				}
			}
			// +ui:description=副本数
			// +ui:order=2
			// // +pattern=^([1-9]\d*)$
			// +err:options={"pattern":"请输入正确的副本数"}
			replicas: *1 | int
		}
		// +ui:title=Workers
		// +ui:order=5
		workers: {
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
					cpu: *"0.1" | string
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
					memory: *"2048Mi" | string
				}
			}
			// +ui:description=副本数
			// +ui:order=2
			// // +pattern=^([1-9]\d*)$
			// +err:options={"pattern":"请输入正确的副本数"}
			replicas: *1 | int
		}

		// +ui:description=Helm Chart 版本号
		// +ui:order=100
		// +ui:options={"disabled":true}
		chartVersion: string
		// +ui:description=镜像版本
		// +ui:order=101
		// +ui:options={"disabled":true}
		images: {
			airflow: {
				// +ui:options={"disabled":true}
				tag: *"v1.0.0-2.9.1" | string
			}
		}
	}
}
