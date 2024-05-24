import "strings"

"superset": {
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
		]
		apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "Application"
				type:       "superset"
			}
		}
	}
	description: "superset"
	type:        "xdefinition"
}

template: {
	_imageRegistry: context["docker_registry"] + "/"
	_databaseName:  "\(strings.Replace(context.namespace+"_superset", "-", "_", -1))"

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
					type: "k8s-objects"
					properties: {
						objects: [
							{
								apiVersion: "source.toolkit.fluxcd.io/v1beta2"
								kind:       "HelmRepository"
								metadata: {
									name:      context["name"]
									namespace: context["namespace"]
								}
								spec: {
									interval: "5m"
									type:     "oci"
									url:      context["helm_repo_url"]
								}
							},
							{
								apiVersion: "source.toolkit.fluxcd.io/v1beta2"
								kind:       "HelmChart"
								metadata: {
									name:      context["name"]
									namespace: context["namespace"]
								}
								spec: {
									chart:    "superset"
									interval: "30s"
									sourceRef: {
										kind: "HelmRepository"
										name: context["name"]
									}
									version: "0.12.10"
								}
							},
							{
								apiVersion: "helm.toolkit.fluxcd.io/v2beta1"
								kind:       "HelmRelease"
								metadata: {
									name:      context["name"]
									namespace: context["namespace"]
								}
								spec: {
									interval:        "5m"
									releaseName:     context["name"]
									targetNamespace: context["namespace"]
									chart: {
										spec: {
											chart: "superset"
											sourceRef: {
												kind: "HelmRepository"
												name: context["name"]
											}
											version: "0.12.10"
										}
									}
									install: {
										disableWait: true
									}
									upgrade: {
										disableWait: true
									}
									values: {
										image: {
											repository: _imageRegistry + "apache/superset"
											tag:        "4.0.0"
										}
										initImage: repository: _imageRegistry + "apache/superset"
										supersetWebsockets: image: repository: _imageRegistry + "oneacrefund/superset-websocket"

										bootstrapScript: ##"""
											#!/bin/bash
											pip install -i https://pypi.tuna.tsinghua.edu.cn/simple clickhouse-connect==0.7.8
											{{ if .Values.init.loadExamples }}
											mkdir -p /app/examples-data
											curl https://registry.linktimecloud.com/repository/raw/examples-data-kdp-v1.0.tar.gz | tar -xz --strip-components=1 -C /app/examples-data
											if [ ! -f ~/bootstrap ]; then echo "Running Superset with uid {{ .Values.runAsUser }}" > ~/bootstrap; fi
											{{- end }}
											"""##
										supersetNode: {
											replicaCount: parameter.supersetNode.replicaCount
											connections: {
												db_name: _databaseName
											}
											if parameter.supersetNode.resources != _|_ {
												resources: parameter.supersetNode.resources
											}
											initContainers: [
												{
													name:  "wait-for-db"
													image: "{{ .Values.initImage.repository }}:{{ .Values.initImage.tag }}"
													envFrom: [
														{
															configMapRef: name: "\(parameter.mysql.mysqlSetting)"
														},
													]
													command: [
														"/bin/sh",
														"-c",
														"dockerize -wait tcp://$MYSQL_HOST:$MYSQL_PORT -timeout 120s",
													]
												},

											]
										}
										extraEnvRaw: [
											{
												name: "DB_PASS"
												valueFrom: {
													secretKeyRef: {
														key:  "MYSQL_PASSWORD"
														name: "\(parameter.mysql.mysqlSecret)"
													}
												}
											},
											{
												name: "DB_USER"
												valueFrom: {
													secretKeyRef: {
														key:  "MYSQL_USER"
														name: "\(parameter.mysql.mysqlSecret)"
													}
												}
											},
											{
												name: "DB_HOST"
												valueFrom: configMapKeyRef: {
													name: "\(parameter.mysql.mysqlSetting)"
													key:  "MYSQL_HOST"
												}
											},
											{
												name: "DB_PORT"
												valueFrom: configMapKeyRef: {
													name: "\(parameter.mysql.mysqlSetting)"
													key:  "MYSQL_PORT"
												}
											},

										]
										configOverrides: {
											my_override:
												"""
												# superset server secret key
												SECRET_KEY = '4fBJrboAjmcQML/vkj0proB1YepAD/HN4do48OZGip5U0uSNkMtxq1oh'

												# Set this API key to enable Mapbox visualizations.
												MAPBOX_API_KEY = "pk.eyJ1IjoieGluZ2NhbiIsImEiOiJjazA0bTF0eWEyMGh6M25wZGNtdmJxZXpzIn0.4MOlFD_220-v9nyvkVfqYg"

												# metadata database https://superset.apache.org/docs/configuration/configuring-superset/#setting-up-a-production-metadata-database
												import urllib
												DATABASE_PASSWORD = urllib.parse.quote_plus(f"{env('DB_PASS')}") # password may contain special characters @
												SQLALCHEMY_DATABASE_URI = f"mysql://{env('DB_USER')}:{DATABASE_PASSWORD}@{env('DB_HOST')}:{env('DB_PORT')}/{env('DB_NAME')}?charset=utf8"
												SQLALCHEMY_EXAMPLES_URI = f"mysql://{env('DB_USER')}:{DATABASE_PASSWORD}@{env('DB_HOST')}:{env('DB_PORT')}/{env('DB_NAME')}_examples?charset=utf8"

												# https://github.com/apache/superset/issues/10354
												WTF_CSRF_ENABLED = False

												# https://superset.apache.org/docs/configuration/configuring-superset/#configuration-behind-a-load-balancer
												ENABLE_PROXY_FIX = True

												# localization
												BABEL_DEFAULT_LOCALE = "en"
												LANGUAGES = {
													"en": {"flag": "us", "name": "English"},
													"zh": {"flag": "cn", "name": "Chinese"},
												}

												"""
										}
										// https: //artifacthub.io/packages/helm/bitnami/redis
										redis: {
											enabled:      true
											architecture: "standalone"
										}
										//  https://github.com/bitnami/charts/tree/main/bitnami/postgresql
										postgresql: {
											enabled: false
										}

										// Async Queries via Celery
										supersetWorker: {
											replicaCount: 0
										}

										init: {
											loadExamples: true
											createAdmin:  true
											adminUser: {
												username: parameter.supersetNode.adminUser.username
												password: parameter.supersetNode.adminUser.password
											}
											initContainers: [
												{
													name:  "create-mysql-database"
													image: context["docker_registry"] + "/bitnami/mysql:8.0.22"
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
												},
											]
											initscript: ##"""
												#!/bin/sh
												set -eu
												echo "Upgrading DB schema..."
												superset db upgrade
												echo "Initializing roles..."
												superset init
												{{ if .Values.init.createAdmin }}
												echo "Creating admin user..."
												superset fab create-admin \
																--username {{ .Values.init.adminUser.username }} \
																--firstname {{ .Values.init.adminUser.firstname }} \
																--lastname {{ .Values.init.adminUser.lastname }} \
																--email {{ .Values.init.adminUser.email }} \
																--password {{ .Values.init.adminUser.password }} \
																|| true
												{{- end }}
												{{ if .Values.init.loadExamples }}
												sed -i 's#https://github.com/apache-superset/examples-data/blob/master/#http://localhost:8000/#' /app/superset/examples/helpers.py
												sed -i 's#https://github.com/apache-superset/examples-data/raw/master/#http://localhost:8000/#g' /app/superset/examples/configs/datasets/examples/* 
												sed -i 's#https://github.com/apache-superset/examples-data/raw/lowercase_columns_examples/#http://localhost:8000/#g' /app/superset/examples/configs/datasets/examples/video_game_sales.yaml 
												sed -i 's#https://raw.githubusercontent.com/apache-superset/examples-data/master/#http://localhost:8000/#g' /app/superset/examples/configs/datasets/examples/* 
												sed -i 's#https://raw.githubusercontent.com/apache-superset/examples-data/lowercase_columns_examples/#http://localhost:8000/#g' /app/superset/examples/configs/datasets/examples/* 
												echo "Starting http server for loading examples"
												python -m http.server --directory /app/examples-data &
												sleep 5
												echo "Loading examples..."
												superset load_examples
												{{- end }}
												if [ -f "{{ .Values.extraConfigMountPath }}/import_datasources.yaml" ]; then
												echo "Importing database connections.... "
												superset import_datasources -p {{ .Values.extraConfigMountPath }}/import_datasources.yaml
												fi
												"""##
										}

									}

								}

							},

						]
					}
					traits: [
						{
							properties: {
								rules: [
									{
										host: context["name"] + "-" + context["namespace"] + "." + context["ingress.root_domain"]
										paths: [
											{
												path:        "/"
												serviceName: context["name"]
												servicePort: 8088
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
							type: "bdos-ingress"
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

		// +ui:description=Superset配置
		// +ui:order=1
		supersetNode: {
			// +ui:description=管理员账号,初次安装配置,更新请在Web应用中修改
			// +ui:order=1
			adminUser: {
				// +ui:description=用户名
				// +ui:options={"showPassword":true}
				// +ui:order=1
				username: *"admin" | string

				// +ui:description=密码
				// +ui:options={"showPassword":true}
				// +ui:order=2
				password: *"admin" | string
			}

			// +minimum=1
			// +ui:description=副本数
			// +ui:order=2
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
					cpu: *"0.1" | string

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
					cpu: *"0.5" | string

					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					// +ui:description=内存
					memory: *"1Gi" | string
				}
			}
		}
	}
}
