import (
	"strconv"
)

import ("encoding/json")

"airflow": {
	annotations: {}
	labels: {}
	attributes: {
		"dynamicParameterMeta": [
			{
				"name":        "dependencies.mysql.host"
				"type":        "ContextSetting"
				"refType":     "mysql"
				"refKey":      "MYSQL_HOST"
				"description": "mysql host"
				"required":    true
			},
			{
				"name":        "dependencies.mysql.port"
				"type":        "ContextSetting"
				"refType":     "mysql"
				"refKey":      "MYSQL_PORT"
				"description": "mysql port"
				"required":    true
			},
			{
				"name":        "dependencies.mysql.user"
				"type":        "ContextSecret"
				"refType":     "mysql"
				"refKey":      "MYSQL_USER"
				"description": "mysql user name"
				"required":    true
			},
			{
				"name":        "dependencies.mysql.pass"
				"type":        "ContextSecret"
				"refType":     "mysql"
				"refKey":      "MYSQL_PASSWORD"
				"description": "mysql password"
				"required":    true
			},
		]
	}
	description: "airflow xdefinition"
	type:        "xdefinition"
}

template: {
	output: {
		"apiVersion": "core.oam.dev/v1beta1"
		"kind":       "Application"
		"metadata": {
			"name":      context.name
			"namespace": context.namespace
			"labels": {
				"app":                context.name
				"app.core.bdos/type": "system"
			}
		}
		"spec": {
			"components": [
				{
					"name": context.name
					"type": "helm"
					"properties": {
						"chart":           "airflow"
						"version":         parameter.chartVersion
						"url":             context["helm_repo_url"]
						"repoType":        "oci"
						"releaseName":     context.name
						"targetNamespace": context.namespace
						"values": {
							"defaultAirflowRepository": context["docker_registry"] + "/apache/airflow"
							defaultAirflowTag:          parameter.images.airflow.tag
							"config": {
								"core": {
									"default_timezone": "Asia/Shanghai"
								}
								"webserver": {
									"default_ui_timezone": "Asia/Shanghai"
								}
								"scheduler": {
									"dag_dir_list_interval": 60
								}
							}
							"data": {
								"metadataConnection": {
									"host":     parameter.dependencies.mysql.host
									"port":     strconv.ParseInt(parameter.dependencies.mysql.port, 10, 64)
									"user":     parameter.dependencies.mysql.host
									"pass":     parameter.dependencies.mysql.pass
									"protocol": "mysql"
									"db":       parameter.dependencies.mysql.database
									"sslmode":  "disable"
								}
							}
							"postgresql": {
								"enabled": false
							}
							"webserverSecretKey": "feab0e05d989b76acb325a8b35e596c9"
							"webserver": {
								"replicas": parameter.webserver.replicas
								"resources": {
									"limits": {
										"cpu":    parameter.webserver.resources.limits.cpu
										"memory": parameter.webserver.resources.limits.memory
									}
									"requests": {
										"cpu":    parameter.webserver.resources.requests.cpu
										"memory": parameter.webserver.resources.requests.memory
									}
								}
								"startupProbe": {
									"timeoutSeconds":   20
									"failureThreshold": 20
									"periodSeconds":    10
								}
							}
							"scheduler": {
								"replicas": parameter.scheduler.replicas
								"resources": {
									"limits": {
										"cpu":    parameter.scheduler.resources.limits.cpu
										"memory": parameter.scheduler.resources.limits.memory
									}
									"requests": {
										"cpu":    parameter.scheduler.resources.requests.cpu
										"memory": parameter.scheduler.resources.requests.memory
									}
								}
								"startupProbe": {
									"timeoutSeconds":   20
									"failureThreshold": 20
									"periodSeconds":    10
								}
							}
							"workers": {
								"replicas":                      parameter.workers.replicas
								"terminationGracePeriodSeconds": 60
								"resources": {
									"limits": {
										"cpu":    parameter.workers.resources.limits.cpu
										"memory": parameter.workers.resources.limits.memory
									}
									"requests": {
										"cpu":    parameter.workers.resources.requests.cpu
										"memory": parameter.workers.resources.requests.memory
									}
								}
							}
							"redis": {
								"enabled":                       true
								"terminationGracePeriodSeconds": 30
							}
							"ingress": {
								"web": {
									"enabled": true
									"hosts": [
										{
											"name": "airflow-web" + context.namespace + "." + context["ingress.root_domain"]
										},
									]
									"ingressClassName": "kong"
								}
							}
							"images": {
								"statsd": {
									"repository": context["docker_registry"] + "/prometheus/statsd-exporter"
									"tag":        "v0.26.1"
								}
								"redis": {
									"repository": context["docker_registry"] + "/redis"
									"tag":        "7-bookworm"
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
				// +ui:description=数据库名称
				database: *"airflow" | string
				// +ui:order=2
				// +ui:description=数据库连接地址
				// +err:options={"required":"请先安装Mysql"}
				host: string
				// +ui:order=3
				// +ui:description=数据库连接端口
				// +err:options={"required":"请先安装Mysql"}
				port: string
				// +ui:order=3
				// +ui:description=数据库连接用户
				// +err:options={"required":"请先安装Mysql"}
				user: string
				// +ui:order=3
				// +ui:description=数据库连接密码
				// +err:options={"required":"请先安装Mysql"}
				pass: string
			}
		}
		// +ui:title=Webserver
		// +ui:order=2
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
		// +ui:order=3
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
		// +ui:order=4
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
				tag: *"2.9.1" | string
			}
		}
	}
}
