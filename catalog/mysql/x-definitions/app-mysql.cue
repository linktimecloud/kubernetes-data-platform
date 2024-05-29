import (
	"encoding/base64"
	"encoding/hex"
	"strings"
)

"mysql": {
	annotations: {}
	labels: {}
	attributes: {
		apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "Application"
				type:       "mysql"
			}
		}
	}
	description: "mysql xdefinition"
	type:        "xdefinition"
}

template: {
	output: {
		{
			"apiVersion": "core.oam.dev/v1beta1"
			"kind":       "Application"
			"metadata": {
				"name":      context["name"]
				"namespace": context["namespace"]
			}
			"spec": {
				"components": [
					{
						"name": "mysql"
						"properties": {
							"chart":           "mysql"
							"releaseName":     "mysql"
							"repoType":        "oci"
							"targetNamespace": context["namespace"]
							"url":             context["helm_repo_url"]
							"values": {
								"architecture": parameter.architecture
								"auth": {
									"username": parameter.auth.username
									"existingSecret": "mysql-" + context.bdc + "-mysql"
								}
								"commonAnnotations": {
									"reloader.stakater.com/auto": "true"
								}
								"global": {
									"imagePullSecrets": [
										context["K8S_IMAGE_PULL_SECRETS_NAME"],
									]
									"imageRegistry": context["docker_registry"]
								}
								"image": {
									"debug":      parameter.debug
									"pullPolicy": "IfNotPresent"
								}
								"initdbScriptsConfigMap": "mysql-initdb"
								"metrics": {
									"enabled": true
									"image": {
										"pullPolicy": "IfNotPresent"
									}
									"resources": {
										"limits": {
											"cpu":    0.3
											"memory": "512Mi"
										}
										"requests": {
											"cpu":    0.1
											"memory": "256Mi"
										}
									}
								}
								"nameOverride": context["bdc"] + "-mysql"
								"primary": {
									extraEnvVars: [
										{
											name:  "TZ"
											value: "Asia/Shanghai"
										},
									]
									"existingConfigmap": "mysql-config"
									"livenessProbe": {
										"enabled":             true
										"failureThreshold":    3
										"initialDelaySeconds": 5
										"periodSeconds":       15
										"successThreshold":    1
										"timeoutSeconds":      10
									}
									"persistence": {
										"enabled":      parameter.persistence.enabled
										"size":         parameter.persistence.size
										"storageClass": context["storage_config.storage_class_mapping.local_disk"]
									}
									"readinessProbe": {
										"enabled":             true
										"failureThreshold":    3
										"initialDelaySeconds": 5
										"periodSeconds":       15
										"successThreshold":    1
										"timeoutSeconds":      10
									}
									"resources": {
										"limits": {
											"cpu":    parameter.resources.limits.cpu
											"memory": parameter.resources.limits.memory
										}
										"requests": {
											"cpu":    parameter.resources.requests.cpu
											"memory": parameter.resources.requests.memory
										}
									}
									"startupProbe": {
										"enabled":             true
										"failureThreshold":    30
										"initialDelaySeconds": 15
										"periodSeconds":       15
										"successThreshold":    1
										"timeoutSeconds":      10
									}
								}
								"secondary": {
									extraEnvVars: [
										{
											name:  "TZ"
											value: "Asia/Shanghai"
										},
									]
									"existingConfigmap": "mysql-config"
									"livenessProbe": {
										"enabled":             true
										"failureThreshold":    3
										"initialDelaySeconds": 5
										"periodSeconds":       15
										"successThreshold":    1
										"timeoutSeconds":      10
									}
									"persistence": {
										"enabled":      parameter.persistence.enabled
										"size":         parameter.persistence.size
										"storageClass": context["storage_config.storage_class_mapping.local_disk"]
									}
									"readinessProbe": {
										"enabled":             true
										"failureThreshold":    3
										"initialDelaySeconds": 5
										"periodSeconds":       15
										"successThreshold":    1
										"timeoutSeconds":      10
									}
									"replicaCount": 1
									"resources": {
										"limits": {
											"cpu":    parameter.resources.limits.cpu
											"memory": parameter.resources.limits.memory
										}
										"requests": {
											"cpu":    parameter.resources.requests.cpu
											"memory": parameter.resources.requests.memory
										}
									}
									"startupProbe": {
										"enabled":             true
										"failureThreshold":    30
										"initialDelaySeconds": 30
										"periodSeconds":       15
										"successThreshold":    1
										"timeoutSeconds":      10
									}
								}
							}
							"version": parameter.version
						}
						"traits": [
							{
								"properties": {
									"endpoints": [
										{
											"port":     9104
											"portName": "metrics"
										},
									]
									"matchLabels": {
										"app": "mysql"
									}
									"monitortype": "service"
									"namespace":   context["namespace"]
								}
								"type": "bdos-monitor"
							},
						]
						"type": "helm"
					},
					{
						"name": "mysql-service-legacy"
						"properties": {
							"objects": [
								{
									"apiVersion": "v1"
									"kind":       "Service"
									"metadata": {
										"annotations": {
											"prometheus.io/port":   "9104"
											"prometheus.io/scrape": "true"
										}
										"name":      context["bdc"] + "-mysql"
										"namespace": context["namespace"]
									}
									"spec": {
										"ports": [
											{
												"name":       "mysql"
												"port":       3306
												"protocol":   "TCP"
												"targetPort": "mysql"
											},
											{
												"name":       "metrics"
												"port":       9104
												"protocol":   "TCP"
												"targetPort": "metrics"
											},
										]
										"selector": {
											"app.kubernetes.io/component": "primary"
											"app.kubernetes.io/instance":  "mysql"
											"app.kubernetes.io/name":      context["bdc"] + "-mysql"
										}
										"sessionAffinity": "None"
										"type":            "ClusterIP"
									}
								},
								{
									"apiVersion": "v1"
									"kind":       "ConfigMap"
									"metadata": {
										"annotations": {
											"app.core.bdos/source": "mysql"
										}
										"name":      "mysql-config"
										"namespace": context["namespace"]
									}
									"data": {
										"my.cnf": parameter.mysqlConfig
									}
								},
								{
									"apiVersion": "v1"
									"kind":       "ConfigMap"
									"metadata": {
										"annotations": {
											"app.core.bdos/source": "mysql"
										}
										"name":      "mysql-initdb"
										"namespace": context["namespace"]
									}
									"data": {
										"ini.sql": """
											GRANT ALL PRIVILEGES ON *.* TO `bdos_dba`@`%` WITH GRANT OPTION;
											FLUSH PRIVILEGES;
										"""
									}
								},
								{
									"apiVersion": "v1"
									"kind":       "Secret"
									"metadata": {
										"annotations": {
											"app.core.bdos/source": "mysql"
										}
										"name":      "mysql-" + context.bdc + "-mysql"
										"namespace": context["namespace"]
									}
									"data": {
										"mysql-password": base64.Encode(null, parameter.auth.password)
										"mysql-replication-password": base64.Encode(null, parameter.auth.replicationPassword)
										"mysql-root-password": base64.Encode(null, parameter.auth.rootPassword)
									}
								}
							]
						}
						"type": "k8s-objects"
					},
				]
			}
		}
	}
	outputs: {
		contextsetting: {
			//生成connect地址端口相关的上下文信息
			"apiVersion": "bdc.kdp.io/v1alpha1"
			"kind":       "ContextSetting"
			"metadata": {
				"name": context.bdc + "-mysql-setting"
				"annotations": {
					"setting.ctx.bdc.kdp.io/type":   "connect"
					"setting.ctx.bdc.kdp.io/origin": "system"
				}
			}
			"spec": {
				"name": "mysql-setting"
				"properties": {
					"MYSQL_HOST": context["bdc"] + "-mysql"
					"MYSQL_PORT": "3306"
				}
				"type": "mysql"
			}
		}

		contextsecret: {
			"apiVersion": "bdc.kdp.io/v1alpha1"
			"kind":       "ContextSecret"
			"metadata": {
				"annotations": {
					"setting.ctx.bdc.kdp.io/origin": "system"
				}
				"name":      context["bdc"] + "-mysql-secret"
				"namespace": ""
			}
			"spec": {
				"type": "mysql"
				"properties": {
					"MYSQL_USER":     base64.Encode(null, parameter.auth.username)
					"MYSQL_PASSWORD": base64.Encode(null, parameter.auth.password)
				}
				"name": "mysql-secret"
			}
		}
	}

	parameter: {
		// +ui:description=mysql套件版本
		// +ui:order=1
		// +ui:options={"disabled": true}
		version: *"9.23.0" | string
		// +ui:description=mysql 镜像是否开启debug模式，默认不开启
		// +ui:order=2
		debug: *false | bool
		// +ui:description=mysql部署模式，standalone: 单机部署，replication: 主备部署。注意: standalone切换replication会导致应用一直处于执行中且无法切换成功。
		// +ui:order=3
		// +ui:hidden={{rootFormData.architecture != ""}}
		architecture: *""| "standalone" | "replication"
		// +ui:description={{rootFormData.architecture == "standalone" ? 'standalone模式鉴权信息': 'replication模式鉴权信息'}}
		// +ui:order=4
		auth: {
			// +ui:description=mysql root的密码, 初次安装时使用此配置，应用更新时更改此配置mysql密码保持不变, 可在应用端修改密码后更新配置，以供其他应用使用。
			// +pattern=(?=.*[A-Z])(?=.*[a-z])(?=.*[0-9])(?=.*[\W_]).{8,}
			// +ui:options={"format": "password", "showPassword": true}
			// +ui:order=1
			// +err:options={"pattern":"密码要求如下:\n1、长度大于8个字符\n2、密码中至少包含大小写字母、数字、特殊字符"}
			rootPassword: *"Kdp@mysql123" | string
			// +ui:description=mysql 备份用户的密码, 初次安装时使用此配置，应用更新时更改此配置mysql密码保持不变, 可在应用端修改密码后更新配置，以供其他应用使用。
			// +pattern=(?=.*[A-Z])(?=.*[a-z])(?=.*[0-9])(?=.*[\W_]).{8,}
			// +ui:options={"showPassword": true}
			// +ui:order=2
			// +err:options={"pattern":"密码要求如下:\n1、长度大于8个字符\n2、密码中至少包含大小写字母、数字、特殊字符"}
			// +ui:hidden={{rootFormData.architecture == "standalone"}}
			replicationPassword: *"Replicat@mysql123" | string
			// +ui:description=mysql dba用户名
			// +ui:options={"disabled": true}
			// +ui:order=3
			username: *"bdos_dba" | string
			// +ui:description=mysql dba密码, 初次安装时使用此配置，应用更新时更改此配置mysql密码保持不变, 可在应用端修改密码后更新配置，以供其他应用使用。
			// +pattern=(?=.*[A-Z])(?=.*[a-z])(?=.*[0-9])(?=.*[\W_]).{8,}
			// +ui:options={"showPassword": true}
			// +ui:order=4
			// +err:options={"pattern":"密码要求如下:\n1、长度大于8个字符\n2、密码中至少包含大小写字母、数字、特殊字符"}
			password: *"KdpDba!mysql123" | string
		}
		// +ui:description=mysql资源配置
		// +ui:order=5
		resources: {
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
				memory: *"4096Mi" | string
			}
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
		}
		// +ui:description=mysql存储配置，默认使用存储资源
		// +ui:order=6
		"persistence": {
			// +ui:description=是否使用存储
			"enabled": *true | bool
			// +ui:hidden={{rootFormData.persistence.enabled === false}}
			// +ui:description=申请存储大小
			// +pattern=^[1-9]\d*(Mi|Gi)$
			// +err:options={"pattern":"请输入正确的存储格式，如1024Mi, 1Gi"}
			"size": *"20Gi" | string
		}
		// +ui:description=mysql应用配置
		// +ui:order=7
		// +ui:options={"type": "textarea", "rows": 40, "placeholder": "[mysqld]\nport=3306"}
		"mysqlConfig": string
	}
}