"kafka-3-cluster": {
	annotations: {}
	labels: {}
	attributes: {
		apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "Application"
				type:       "kafka-3-cluster"
			}
		}
	}
	description: "kafka-operator-kraft xdefinition"
	type:        "xdefinition"
}

template: {
	output: {
		"apiVersion": "core.oam.dev/v1beta1"
		"kind":       "Application"
		"metadata": {
			"name":      context["name"]
			"namespace": context["namespace"]
		}
		"spec": {
			"components": [
				{
					"name": context["name"]
					"type": "raw"
					"properties": {
						"apiVersion": "kafka.strimzi.io/v1beta2"
						"kind":       "Kafka"
						"metadata": {
							"name":      context.name
							"namespace": context.namespace
							"labels": {
								"app": context.name
							}
						}
						"spec": {
							"kafka": {
								"version":  "3.4.1"
								"image":    context["docker_registry"] + "/" + parameter.image
								"replicas": parameter.replicas
								"resources": {
									"requests": {
										"cpu":    parameter.resources.requests.cpu
										"memory": parameter.resources.requests.memory
									}
									"limits": {
										"cpu":    parameter.resources.limits.cpu
										"memory": parameter.resources.limits.memory
									}
								}
								"logging": {
									"type": "inline"
									"loggers": {
										"kafka.root.logger.level":                                                               "INFO"
										"log4j.rootLogger":                                                                      "WARN, stdout"
										"log4j.appender.stdout":                                                                 "org.apache.log4j.ConsoleAppender"
										"log4j.appender.stdout.layout":                                                          "org.apache.log4j.PatternLayout"
										"log4j.appender.stdout.layout.ConversionPattern":                                        "[%d] %p %m (%c)%n"
										"log4j.logger.kafka.request.logger":                                                     "WARN, requestAppender"
										"log4j.logger.kafka.network.RequestChannel$":                                            "WARN, requestAppender"
										"log4j.logger.kafka.controller":                                                         "INFO, controllerAppender"
										"log4j.logger.kafka.log.LogCleaner":                                                     "INFO, cleanerAppender"
										"log4j.logger.state.change.logger":                                                      "WARN, stateChangeAppender"
										"log4j.logger.kafka.authorizer.logger":                                                  "INFO, authorizerAppender"
										"log4j.logger.org.apache.zookeeper":                                                     "INFO"
										"log4j.logger.kafka":                                                                    "INFO"
										"log4j.logger.org.apache.kafka":                                                         "INFO"
										"log4j.logger.org.apache.kafka.common.security.authenticator.SaslServerCallbackHandler": "WARN"
									}
								}
								"readinessProbe": {
									"initialDelaySeconds": 30
									"timeoutSeconds":      5
									"failureThreshold":    20
								}
								"livenessProbe": {
									"initialDelaySeconds": 30
									"timeoutSeconds":      5
									"failureThreshold":    20
								}
								"jvmOptions": {
									"-XX": {
										"MaxRAMPercentage":    85
										"UseContainerSupport": true
									}
								}
								if parameter.metrics.enable {
									"metricsConfig": {
										"type": "jmxPrometheusExporter"
										"valueFrom": {
											"configMapKeyRef": {
												"name": "kafka-metrics"
												"key":  "kafka-metrics-config.yml"
											}
										}
									}
								}
								"listeners": [
									{
										"name": "plain"
										"port": parameter.listeners.port
										"type": parameter.listeners.type
										"tls":  false
										if parameter.listeners.type == "nodeport" {
											"configuration": {
												"bootstrap": {
													"nodePort": parameter.listeners.nodePort
												}
											}
										}
									},
								]
								"config": {
									"log.retention.bytes":           -1
									"log.message.format.version":    "3.4"
									"inter.broker.protocol.version": "3.4"
									for k, v in parameter.config {
										"\(k)": v
									}
								}
								"storage": {
									"deleteClaim": false
									"type":        "persistent-claim"
									"class":       context["storage_config.storage_class_mapping.local_disk"]
									"size":        parameter.storage.size
								}
								"template": {
									"pod": {
										"affinity": {
											"podAntiAffinity": {
												"preferredDuringSchedulingIgnoredDuringExecution": [
													{
														"weight": 10
														"podAffinityTerm": {
															"labelSelector": {
																"matchExpressions": [
																	{
																		"key":      "app.kubernetes.io/name"
																		"operator": "In"
																		"values": [
																			"kafka",
																		]
																	},
																]
															}
															"topologyKey": "kubernetes.io/hostname"
														}
													},
												]
											}
										}
									}
									"contextConfigMap": {
										"labels": {
											"setting.ctx.bdc.kdp.io/source": "config"
										}
										"annotations": {
											"setting.ctx.bdc.kdp.io/type":   "kafka"
											"setting.ctx.bdc.kdp.io/origin": "system"
											"setting.ctx.bdc.kdp.io/adopt":  "true"
											"setting.ctx.bdc.kdp.io/source": "configmap"
										}
									}
								}
							}
							"zookeeper": {
								if parameter.metrics.enable {
									"config": {
										"metricsProvider.className":     "org.apache.zookeeper.metrics.prometheus.PrometheusMetricsProvider"
										"metricsProvider.httpPort":      9141
										"metricsProvider.exportJvmInfo": true
									}
								}
								"image":    context["docker_registry"] + "/" + parameter.image
								"replicas": parameter.zookeeper.replicas
								"resources": {
									"requests": {
										"cpu":    parameter.zookeeper.resources.requests.cpu
										"memory": parameter.zookeeper.resources.requests.memory
									}
									"limits": {
										"cpu":    parameter.zookeeper.resources.limits.cpu
										"memory": parameter.zookeeper.resources.limits.memory
									}
								}
								"logging": {
									"type": "inline"
									"loggers": {
										"zookeeper.root.logger": "INFO"
									}
								}
								"jvmOptions": {
									"-XX": {
										"MaxRAMPercentage":    85
										"UseContainerSupport": true
									}
								}
								"storage": {
									"deleteClaim": false
									"type":        "persistent-claim"
									"class":       context["storage_config.storage_class_mapping.local_disk"]
									"size":        parameter.zookeeper.storage.size
								}
								"template": {
									"pod": {
										"affinity": {
											"podAntiAffinity": {
												"preferredDuringSchedulingIgnoredDuringExecution": [
													{
														"weight": 100
														"podAffinityTerm": {
															"labelSelector": {
																"matchExpressions": [
																	{
																		"key":      "app.kubernetes.io/name"
																		"operator": "In"
																		"values": [
																			"zookeeper",
																		]
																	},
																]
															}
															"topologyKey": "kubernetes.io/hostname"
														}
													},
												]
											}
										}
									}
								}
							}
						}
					}
					"traits": [
						{
							"properties": {
								"endpoints": [
									{
										"port":     9404
										"portName": "tcp-prometheus"
									},
								]
								"matchLabels": {
									"app":                    context["name"]
									"app.kubernetes.io/name": "kafka"
								}
								"monitortype": "pod"
							}
							"type": "bdos-monitor"
						},
						{
							"properties": {
								"endpoints": [
									{
										"port":     9141
										"portName": "metrics-zk"
									},
								]
								"matchLabels": {
									"app":                    context["name"]
									"app.kubernetes.io/name": "kafka-zookeeper"
								}
								"monitortype": "service"
							}
							"type": "bdos-monitor"
						},
						{
							"properties": {
								"groups": [
									{
										"name": context["namespace"] + "-" + context["name"] + ".rules"
										"rules": [
											{
												"alert": context["namespace"] + "-" + context["name"] + "-UnderReplicatedPartitions"
												"annotations": {
													"description": "There are {{ $value }} under replicated partitions on {{ $labels.pod }}"
													"summary":     "Kafka under replicated partitions"
												}
												"duration": "60s"
												"expr":     "kafka_server_replicamanager_underreplicatedpartitions \u003e 0"
												"labels": {
													"severity": "warning"
												}
											},
											{
												"alert": context["namespace"] + "-" + context["name"] + "-AbnormalControllerState"
												"annotations": {
													"description": "There are {{ $value }} active controllers in the cluster"
													"summary":     "Kafka abnormal controller state"
												}
												"duration": "60s"
												"expr":     "sum(kafka_controller_kafkacontroller_activecontrollercount) by (job) != 1"
												"labels": {
													"severity": "warning"
												}
											},
											{
												"alert": context["namespace"] + "-" + context["name"] + "-OfflinePartitions"
												"annotations": {
													"description": "One or more partitions have no leader"
													"summary":     "Kafka offline partitions"
												}
												"duration": "60s"
												"expr":     "sum(kafka_controller_kafkacontroller_offlinepartitionscount) \u003e 0"
												"labels": {
													"severity": "warning"
												}
											},
											{
												"alert": context["namespace"] + "-" + context["name"] + "-UnderMinIsrPartitionCount"
												"annotations": {
													"description": "There are {{ $value }} partitions under the min ISR on {{ $labels.pod }}"
													"summary":     "Kafka under min ISR partitions"
												}
												"duration": "60s"
												"expr":     "kafka_server_replicamanager_underminisrpartitioncount \u003e 0"
												"labels": {
													"severity": "warning"
												}
											},
											{
												"alert": context["namespace"] + "-" + context["name"] + "-OfflineLogDirectoryCount"
												"annotations": {
													"description": "There are {{ $value }} offline log directories on {{ $labels.pod }}"
													"summary":     "Kafka offline log directories"
												}
												"duration": "60s"
												"expr":     "kafka_log_logmanager_offlinelogdirectorycount \u003e 0"
												"labels": {
													"severity": "warning"
												}
											},
											{
												"alert": context["namespace"] + "-" + context["name"] + "-ScrapeProblem"
												"annotations": {
													"description": "Prometheus was unable to scrape metrics from {{ $labels.namespace }}/{{ $labels.pod }} for more than 3 minutes"
													"summary":     "Prometheus unable to scrape metrics from {{ $labels.namespace }}/{{ $labels.pod }}"
												}
												"duration": "3m"
												"expr":     "up{namespace!~\"openshift-.+\",pod=~\".+-kafka-[0-9]+\"} == 0"
												"labels": {
													"severity": "major"
												}
											},
											{
												"alert": context["namespace"] + "-" + context["name"] + "-ClusterOperatorContainerDown"
												"annotations": {
													"description": "The Cluster Operator has been down for longer than 90 seconds"
													"summary":     "Cluster Operator down"
												}
												"duration": "1m"
												"expr":     "count((container_last_seen{container=\"strimzi-cluster-operator\"} \u003e (time() - 90))) \u003c 1 or absent(container_last_seen{container=\"strimzi-cluster-operator\"})"
												"labels": {
													"severity": "major"
												}
											},
											{
												"alert": context["namespace"] + "-" + context["name"] + "-KafkaBrokerContainersDown"
												"annotations": {
													"description": "All `kafka` containers have been down or in CrashLookBackOff status for 3 minutes"
													"summary":     "All `kafka` containers down or in CrashLookBackOff status"
												}
												"duration": "3m"
												"expr":     "absent(container_last_seen{container=\"kafka\",pod=~\".+-kafka-[0-9]+\"})"
												"labels": {
													"severity": "major"
												}
											},
											{
												"alert": context["namespace"] + "-" + context["name"] + "-KafkaContainerRestartedInTheLast5Minutes"
												"annotations": {
													"description": "One or more Kafka containers were restarted too often within the last 5 minutes"
													"summary":     "One or more Kafka containers restarted too often"
												}
												"duration": "5m"
												"expr":     "count(count_over_time(container_last_seen{container=\"kafka\"}[5m])) \u003e 2 * count(container_last_seen{container=\"kafka\",pod=~\".+-kafka-[0-9]+\"})"
												"labels": {
													"severity": "warning"
												}
											},
											{
												"alert": context["namespace"] + "-" + context["name"] + "-KafkaPvUsageIsOver70%"
												"annotations": {
													"description": "{{ $labels.namespace }}/{{ $labels.pod }} kafka broker data size is over 70% of pv capacity"
													"summary":     "Kafka broker data size is over 70% of pv capacity"
												}
												"duration": "10s"
												"expr":     "max(kubelet_volume_stats_available_bytes/kubelet_volume_stats_capacity_bytes{persistentvolumeclaim=~\".*kafka-[0-9]+\"})by(namespace,node,persistentvolumeclaim)\u003c=0.3"
												"labels": {
													"severity": "major"
												}
											},
										]
									},
								]
								"labels": {
									"prometheus": "k8s"
									"release":    "prometheus"
									"role":       "alert-rules"
								}
							}
							"type": "bdos-prometheus-rules"
						},
						{
							"properties": {
								"dashboard_data": {
									"strimzi-kafka-dashboard.json": "{\"annotations\":{\"list\":[{\"builtIn\":1,\"datasource\":{\"type\":\"datasource\",\"uid\":\"grafana\"},\"enable\":true,\"hide\":true,\"iconColor\":\"rgba(0, 211, 255, 1)\",\"name\":\"Annotations & Alerts\",\"target\":{\"limit\":100,\"matchAny\":false,\"tags\":[],\"type\":\"dashboard\"},\"type\":\"dashboard\"}]},\"editable\":true,\"fiscalYearStartMonth\":0,\"graphTooltip\":0,\"id\":28,\"links\":[],\"liveNow\":false,\"panels\":[{\"collapsed\":false,\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":0},\"id\":119,\"panels\":[],\"title\":\"Kakfa Cluster\",\"type\":\"row\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Number of brokers online\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"#d44a3a\",\"value\":null},{\"color\":\"red\",\"value\":2},{\"color\":\"semi-dark-green\",\"value\":3}]},\"unit\":\"none\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":3,\"x\":0,\"y\":1},\"id\":46,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"area\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"showPercentChange\":false,\"textMode\":\"auto\",\"wideLayout\":true},\"pluginVersion\":\"10.3.3\",\"repeatDirection\":\"h\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"count(sum(kafka_server_replicamanager_leadercount{namespace=\\\"$namespace\\\",pod=~\\\"$strimzi_cluster_name.*\\\"})by(pod))\",\"format\":\"time_series\",\"hide\":false,\"intervalFactor\":1,\"legendFormat\":\"\",\"refId\":\"A\"}],\"title\":\"Brokers Online\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Number of active controllers in the cluster\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"semi-dark-green\",\"value\":null},{\"color\":\"#e5ac0e\",\"value\":2}]},\"unit\":\"none\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":3,\"x\":3,\"y\":1},\"id\":36,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"/^pod$/\",\"values\":false},\"showPercentChange\":false,\"textMode\":\"auto\",\"wideLayout\":true},\"pluginVersion\":\"10.3.3\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"kafka_controller_kafkacontroller_activecontrollercount{namespace=\\\"$namespace\\\",pod=~\\\"$strimzi_cluster_name.*\\\"}==1\",\"format\":\"table\",\"hide\":false,\"instant\":true,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"\",\"range\":false,\"refId\":\"A\"}],\"title\":\"Active Controller\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Replicas that are online\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"#d44a3a\",\"value\":null},{\"color\":\"rgba(237, 129, 40, 0.89)\",\"value\":0},{\"color\":\"semi-dark-green\",\"value\":0}]},\"unit\":\"none\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":3,\"x\":6,\"y\":1},\"id\":40,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"showPercentChange\":false,\"textMode\":\"auto\",\"wideLayout\":true},\"pluginVersion\":\"10.3.3\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(kafka_server_replicamanager_partitioncount{namespace=\\\"$namespace\\\",pod=~\\\"$strimzi_cluster_name.*\\\"})\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"\",\"refId\":\"A\"}],\"title\":\"Online Replicas\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Number of partitions that don’t have an active leader and are hence not writable or readable\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"semi-dark-green\",\"value\":null},{\"color\":\"#ef843c\",\"value\":1},{\"color\":\"red\",\"value\":1}]},\"unit\":\"none\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":3,\"x\":9,\"y\":1},\"id\":32,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"showPercentChange\":false,\"textMode\":\"auto\",\"wideLayout\":true},\"pluginVersion\":\"10.3.3\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"sum(kafka_controller_kafkacontroller_offlinepartitionscount{namespace=\\\"$namespace\\\",pod=~\\\"$strimzi_cluster_name.*\\\"})\",\"format\":\"time_series\",\"hide\":false,\"intervalFactor\":1,\"refId\":\"A\"}],\"title\":\"Offline Partitions\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Number of under-replicated partitions (| ISR | < | all replicas |).\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"semi-dark-green\",\"value\":null},{\"color\":\"rgba(237, 129, 40, 0.89)\",\"value\":1},{\"color\":\"#bf1b00\",\"value\":5}]},\"unit\":\"none\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":3,\"x\":12,\"y\":1},\"id\":30,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"showPercentChange\":false,\"textMode\":\"auto\",\"wideLayout\":true},\"pluginVersion\":\"10.3.3\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(kafka_server_replicamanager_underreplicatedpartitions{namespace=\\\"$namespace\\\",pod=~\\\"$strimzi_cluster_name.*\\\"})\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"\",\"refId\":\"A\"}],\"title\":\"Under Replicated Partitions\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Number of brokers online\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"decimals\":0,\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"min\":-2,\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"semi-dark-green\",\"value\":null},{\"color\":\"#EAB839\",\"value\":100},{\"color\":\"red\",\"value\":500}]},\"unit\":\"none\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":3,\"x\":15,\"y\":1},\"id\":137,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"showPercentChange\":false,\"textMode\":\"auto\",\"wideLayout\":true},\"pluginVersion\":\"10.3.3\",\"repeatDirection\":\"h\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"avg(kafka_server_zookeeperclientmetrics_zookeeperrequestlatencyms{namespace=\\\"$namespace\\\",pod=~\\\"$broker\\\",quantile=\\\"0.95\\\"})\",\"format\":\"time_series\",\"hide\":false,\"intervalFactor\":1,\"legendFormat\":\"\",\"refId\":\"A\"}],\"title\":\"zk request latency(ms)\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Number of partitions which are under their minimum in sync replica count (| ISR | < | min.insync.replicas |)\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"color\":\"#508642\",\"text\":\"0\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"semi-dark-green\",\"value\":null},{\"color\":\"#ef843c\",\"value\":1},{\"color\":\"#bf1b00\",\"value\":1}]},\"unit\":\"none\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":3,\"x\":18,\"y\":1},\"id\":103,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"showPercentChange\":false,\"textMode\":\"auto\",\"wideLayout\":true},\"pluginVersion\":\"10.3.3\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(kafka_cluster_partition_underminisr{namespace=\\\"$namespace\\\",pod=~\\\"$strimzi_cluster_name.*\\\"})\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"\",\"refId\":\"A\"}],\"title\":\"Partitions under minISR\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Number of partitions which are at their minimum in sync replica count (| ISR | == | min.insync.replicas |)\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"color\":\"#508642\",\"text\":\"0\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"#508642\",\"value\":null},{\"color\":\"semi-dark-green\",\"value\":5},{\"color\":\"yellow\",\"value\":10},{\"color\":\"red\",\"value\":20}]},\"unit\":\"none\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":3,\"x\":21,\"y\":1},\"id\":102,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"showPercentChange\":false,\"textMode\":\"auto\",\"wideLayout\":true},\"pluginVersion\":\"10.3.3\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"sum(kafka_cluster_partition_atminisr{namespace=\\\"$namespace\\\",pod=~\\\"$strimzi_cluster_name.*\\\"})\",\"format\":\"time_series\",\"hide\":false,\"intervalFactor\":2,\"refId\":\"A\"}],\"title\":\"Partitions at minISR\",\"type\":\"stat\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"broker controller history\",\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":0,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":6,\"x\":0,\"y\":5},\"hiddenSeries\":false,\"id\":110,\"legend\":{\"alignAsTable\":false,\"avg\":false,\"current\":true,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"kafka_controller_kafkacontroller_activecontrollercount{namespace=\\\"$namespace\\\",pod=~\\\"$strimzi_cluster_name.*\\\"}==1\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Broker controller\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1485\",\"decimals\":0,\"format\":\"string\",\"label\":\"\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1486\",\"format\":\"short\",\"logBase\":1,\"show\":false}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"broker partition leader/online/offline count\",\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":0,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":6,\"x\":6,\"y\":5},\"hiddenSeries\":false,\"id\":112,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(kafka_server_replicamanager_leadercount{namespace=\\\"$namespace\\\",pod=~\\\"$broker\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"leader {{pod}}\",\"range\":true,\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"sum(kafka_server_replicamanager_partitioncount{namespace=\\\"$namespace\\\",pod=~\\\"$broker\\\"}) by (pod)\",\"hide\":false,\"legendFormat\":\"online {{pod}}\",\"range\":true,\"refId\":\"B\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"sum(kafka_server_replicamanager_offlinereplicacount{namespace=\\\"$namespace\\\",pod=~\\\"$broker\\\"}) by (pod)\",\"hide\":false,\"legendFormat\":\"offline {{pod}}\",\"range\":true,\"refId\":\"C\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Broker partition detail\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1485\",\"decimals\":0,\"format\":\"string\",\"label\":\"\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1486\",\"format\":\"short\",\"logBase\":1,\"show\":false}],\"yaxis\":{\"align\":false}},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"partition under minISR\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"custom\":{\"align\":\"auto\",\"cellOptions\":{\"type\":\"auto\"},\"inspect\":false},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":7,\"w\":6,\"x\":12,\"y\":5},\"id\":138,\"links\":[],\"options\":{\"cellHeight\":\"sm\",\"footer\":{\"countRows\":false,\"fields\":\"\",\"reducer\":[\"sum\"],\"show\":false},\"showHeader\":true,\"sortBy\":[{\"desc\":true,\"displayName\":\"Under minISR\"}]},\"pluginVersion\":\"10.3.3\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"sum(kafka_cluster_partition_underminisr{namespace=\\\"$namespace\\\",pod=~\\\"$strimzi_cluster_name.*\\\",topic=~\\\"$kafka_topic\\\",partition=~\\\"$partition\\\"})by(topic,partition) == 1\",\"format\":\"table\",\"hide\":false,\"instant\":true,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"__auto\",\"range\":false,\"refId\":\"A\"}],\"title\":\"Partition under minISR\",\"transformations\":[{\"id\":\"filterFieldsByName\",\"options\":{\"include\":{\"names\":[\"partition\",\"topic\",\"Value\"]}}},{\"id\":\"organize\",\"options\":{\"excludeByName\":{},\"indexByName\":{\"Value\":2,\"partition\":1,\"topic\":0},\"renameByName\":{\"Value\":\"Under minISR\"}}},{\"id\":\"sortBy\",\"options\":{\"fields\":{},\"sort\":[{\"desc\":true,\"field\":\"Under minISR\"}]}},{\"id\":\"sortBy\",\"options\":{\"fields\":{},\"sort\":[{\"desc\":false,\"field\":\"topic\"}]}}],\"type\":\"table\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"partition at minISR maybe unusable when one broker shut down\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"custom\":{\"align\":\"auto\",\"cellOptions\":{\"type\":\"auto\"},\"inspect\":false},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":7,\"w\":6,\"x\":18,\"y\":5},\"id\":111,\"links\":[],\"options\":{\"cellHeight\":\"sm\",\"footer\":{\"countRows\":false,\"fields\":\"\",\"reducer\":[\"sum\"],\"show\":false},\"showHeader\":true,\"sortBy\":[{\"desc\":true,\"displayName\":\"at minISR\"}]},\"pluginVersion\":\"10.3.3\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"sum(kafka_cluster_partition_atminisr{namespace=\\\"$namespace\\\",pod=~\\\"$strimzi_cluster_name.*\\\",topic=~\\\"$kafka_topic\\\",partition=~\\\"$partition\\\"})by(topic,partition) == 1\",\"format\":\"table\",\"hide\":false,\"instant\":true,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"__auto\",\"range\":false,\"refId\":\"A\"}],\"title\":\"Partition at minISR\",\"transformations\":[{\"id\":\"filterFieldsByName\",\"options\":{\"include\":{\"names\":[\"partition\",\"topic\",\"Value\"]}}},{\"id\":\"sortBy\",\"options\":{\"fields\":{},\"sort\":[{\"desc\":true,\"field\":\"Value\"}]}},{\"id\":\"sortBy\",\"options\":{\"fields\":{},\"sort\":[{\"desc\":false,\"field\":\"topic\"}]}},{\"id\":\"organize\",\"options\":{\"excludeByName\":{},\"indexByName\":{\"partition\":1,\"topic\":0},\"renameByName\":{\"Value\":\"at minISR\"}}}],\"type\":\"table\"},{\"collapsed\":false,\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":12},\"id\":129,\"panels\":[],\"title\":\"Topic\",\"type\":\"row\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisBorderShow\":false,\"axisCenteredZero\":false,\"axisColorMode\":\"text\",\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"insertNulls\":false,\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":7,\"w\":24,\"x\":0,\"y\":13},\"id\":130,\"links\":[],\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\",\"showLegend\":true},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"count(sum(kafka_cluster_partition_laststableoffsetlag{namespace=\\\"$namespace\\\",pod=~\\\"$broker\\\"}) by (topic) )\",\"format\":\"time_series\",\"hide\":false,\"instant\":false,\"intervalFactor\":1,\"legendFormat\":\"topics num\",\"range\":true,\"refId\":\"A\"}],\"title\":\"Topics\",\"transformations\":[],\"type\":\"timeseries\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":24,\"x\":0,\"y\":20},\"hiddenSeries\":false,\"id\":91,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(kafka_log_log_size{namespace=\\\"$namespace\\\",pod=~\\\"$broker\\\",topic=~\\\"$kafka_topic\\\",partition=~\\\"$partition\\\"})by(topic)\",\"format\":\"time_series\",\"instant\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{topic}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Log Size by topic\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:123\",\"format\":\"bytes\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:124\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":9,\"w\":12,\"x\":0,\"y\":28},\"hiddenSeries\":false,\"id\":133,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(kafka_log_log_size{namespace=\\\"$namespace\\\",pod=~\\\"$broker\\\",topic=~\\\"$kafka_topic\\\",partition=~\\\"$partition\\\"})by(pod)\",\"format\":\"time_series\",\"instant\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Log Size by node\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:123\",\"format\":\"bytes\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:124\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":9,\"w\":12,\"x\":12,\"y\":28},\"hiddenSeries\":false,\"id\":132,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"kafka_log_log_size{namespace=\\\"$namespace\\\",pod=~\\\"$broker\\\",topic=~\\\"$kafka_topic\\\",partition=~\\\"$partition\\\"}\",\"format\":\"time_series\",\"instant\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{topic}}:{{partition}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Log Size by topic partiton\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:123\",\"format\":\"bytes\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:124\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"collapsed\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":37},\"id\":28,\"panels\":[],\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"refId\":\"A\"}],\"title\":\"Broker\",\"type\":\"row\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Aggregated Kafka broker pods CPU usage\",\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":6,\"x\":0,\"y\":38},\"hiddenSeries\":false,\"id\":81,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"sum(rate(container_cpu_usage_seconds_total{namespace=\\\"$namespace\\\",pod=~\\\"$broker\\\",container=\\\"kafka\\\"}[5m])) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"CPU Usage\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:319\",\"format\":\"short\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:320\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Kafka broker pods memory usage\",\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":6,\"x\":6,\"y\":38},\"hiddenSeries\":false,\"id\":82,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(container_memory_usage_bytes{namespace=\\\"$namespace\\\",pod=~\\\"$broker\\\",container=\\\"kafka\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Memory Usage\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"bytes\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Kafka broker pods disk usage\",\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":6,\"x\":12,\"y\":38},\"hiddenSeries\":false,\"id\":83,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"avg(kubelet_volume_stats_available_bytes{namespace=\\\"$namespace\\\",persistentvolumeclaim=~\\\"data-$strimzi_cluster_name-kafka-[0-9]+\\\",persistentvolumeclaim=~\\\"data-$broker\\\"})by(persistentvolumeclaim)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{persistentvolumeclaim}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Available Disk Space\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"bytes\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Open File Descriptors\",\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":6,\"x\":18,\"y\":38},\"hiddenSeries\":false,\"id\":107,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"process_open_fds{namespace=\\\"$namespace\\\",pod=~\\\"$broker\\\",container=\\\"kafka\\\"}\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Open File Descriptors\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"none\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Total incoming byte rate\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"color\":\"rgba(237, 129, 40, 0.89)\",\"text\":\"0\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"#d44a3a\",\"value\":null},{\"color\":\"rgba(237, 129, 40, 0.89)\",\"value\":0},{\"color\":\"#299c46\",\"value\":2}]},\"unit\":\"Bps\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":6,\"x\":0,\"y\":45},\"id\":98,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"showPercentChange\":false,\"textMode\":\"auto\",\"wideLayout\":true},\"pluginVersion\":\"10.3.3\",\"repeatDirection\":\"h\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(irate(kafka_server_brokertopicmetrics_bytesin_total{namespace=\\\"$namespace\\\",topic=~\\\"$kafka_topic\\\",topic!=\\\"\\\",pod=~\\\"$broker\\\"}[1m]))\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"\",\"refId\":\"A\"}],\"title\":\"Total Incoming Byte Rate\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Total outgoing byte rate\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"color\":\"rgba(237, 129, 40, 0.89)\",\"text\":\"0\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"#d44a3a\",\"value\":null},{\"color\":\"rgba(237, 129, 40, 0.89)\",\"value\":0},{\"color\":\"#299c46\",\"value\":2}]},\"unit\":\"Bps\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":6,\"x\":6,\"y\":45},\"id\":99,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"showPercentChange\":false,\"textMode\":\"auto\",\"wideLayout\":true},\"pluginVersion\":\"10.3.3\",\"repeatDirection\":\"h\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(irate(kafka_server_brokertopicmetrics_bytesout_total{namespace=\\\"$namespace\\\",topic=~\\\"$kafka_topic\\\",topic!=\\\"\\\",pod=~\\\"$broker\\\"}[1m]))\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"\",\"refId\":\"A\"}],\"title\":\"Total Outgoing Byte Rate\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Incoming messages rate\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"color\":\"rgba(237, 129, 40, 0.89)\",\"text\":\"0\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"#d44a3a\",\"value\":null},{\"color\":\"rgba(237, 129, 40, 0.89)\",\"value\":0},{\"color\":\"#299c46\",\"value\":2}]},\"unit\":\"wps\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":6,\"x\":12,\"y\":45},\"id\":100,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"showPercentChange\":false,\"textMode\":\"auto\",\"wideLayout\":true},\"pluginVersion\":\"10.3.3\",\"repeatDirection\":\"h\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"sum(irate(kafka_server_brokertopicmetrics_messagesin_total{namespace=\\\"$namespace\\\",topic=~\\\"$kafka_topic\\\",topic!=\\\"\\\",pod=~\\\"$broker\\\"}[1m]))\",\"format\":\"time_series\",\"hide\":false,\"intervalFactor\":1,\"legendFormat\":\"\",\"refId\":\"A\"}],\"title\":\"Incoming Messages Rate\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Total produce request rate\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"color\":\"rgba(237, 129, 40, 0.89)\",\"text\":\"0\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"#d44a3a\",\"value\":null},{\"color\":\"rgba(237, 129, 40, 0.89)\",\"value\":0},{\"color\":\"#299c46\",\"value\":2}]},\"unit\":\"reqps\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":6,\"x\":18,\"y\":45},\"id\":101,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"showPercentChange\":false,\"textMode\":\"auto\",\"wideLayout\":true},\"pluginVersion\":\"10.3.3\",\"repeatDirection\":\"h\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"sum(irate(kafka_server_brokertopicmetrics_totalproducerequests_total{namespace=\\\"$namespace\\\",topic=~\\\"$kafka_topic\\\",topic!=\\\"\\\",pod=~\\\"$broker\\\"}[1m]))\",\"format\":\"time_series\",\"hide\":false,\"intervalFactor\":1,\"legendFormat\":\"\",\"refId\":\"A\"}],\"title\":\"Total Produce Request Rate\",\"type\":\"stat\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Byte rate\",\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":12,\"x\":0,\"y\":49},\"hiddenSeries\":false,\"id\":44,\"legend\":{\"alignAsTable\":false,\"avg\":false,\"current\":false,\"hideEmpty\":false,\"hideZero\":false,\"max\":false,\"min\":false,\"rightSide\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"sum(irate(kafka_server_brokertopicmetrics_bytesin_total{namespace=\\\"$namespace\\\",topic=~\\\"$kafka_topic\\\",topic!=\\\"\\\",pod=~\\\"$broker\\\"}[1m]))\",\"format\":\"time_series\",\"hide\":false,\"instant\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"Total Incoming Byte Rate\",\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"sum(irate(kafka_server_brokertopicmetrics_bytesout_total{namespace=\\\"$namespace\\\",topic=~\\\"$kafka_topic\\\",topic!=\\\"\\\",pod=~\\\"$broker\\\"}[1m]))\",\"format\":\"time_series\",\"hide\":false,\"intervalFactor\":1,\"legendFormat\":\"Total Outgoing Byte Rate\",\"refId\":\"B\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Byte Rate\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"bytes\",\"label\":\"\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":12,\"x\":12,\"y\":49},\"hiddenSeries\":false,\"id\":58,\"legend\":{\"alignAsTable\":false,\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(irate(kafka_server_brokertopicmetrics_messagesin_total{namespace=\\\"$namespace\\\",topic=~\\\"$kafka_topic\\\",topic!=\\\"\\\",pod=~\\\"$broker\\\"}[1m]))\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"Total Incoming Messages Rate\",\"refId\":\"D\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Messages In Per Second(avg)\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"short\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Produce request rate\",\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":12,\"x\":0,\"y\":57},\"hiddenSeries\":false,\"id\":50,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(irate(kafka_server_brokertopicmetrics_totalproducerequests_total{namespace=\\\"$namespace\\\",topic=~\\\"$kafka_topic\\\",topic!=\\\"\\\",pod=~\\\"$broker\\\"}[1m]))\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"Total Produce Request Rate\",\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"sum(irate(kafka_server_brokertopicmetrics_failedproducerequests_total{namespace=\\\"$namespace\\\",topic=~\\\"$kafka_topic\\\",topic!=\\\"\\\",pod=~\\\"$broker\\\"}[1m]))\",\"format\":\"time_series\",\"hide\":false,\"intervalFactor\":1,\"legendFormat\":\"Failed Produce Request Rate\",\"refId\":\"B\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Produce Request Rate\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"short\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Fetch request rate\",\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":12,\"x\":12,\"y\":57},\"hiddenSeries\":false,\"id\":56,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"sum(irate(kafka_server_brokertopicmetrics_totalfetchrequests_total{namespace=\\\"$namespace\\\",topic=~\\\"$kafka_topic\\\",topic!=\\\"\\\",pod=~\\\"$broker\\\"}[1m]))\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"Fetch Request Rate\",\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"  sum(irate(kafka_server_brokertopicmetrics_failedfetchrequests_total{namespace=\\\"$namespace\\\",topic=~\\\"$kafka_topic\\\",topic!=\\\"\\\",pod=~\\\"$broker\\\"}[1m]))\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"Failed Fetch Request Rate\",\"refId\":\"B\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Fetch Request Rate\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"short\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Average percentage of time network processor is idle\",\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":12,\"x\":0,\"y\":65},\"hiddenSeries\":false,\"id\":60,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"kafka_network_socketserver_networkprocessoravgidle_percent{namespace=\\\"$namespace\\\",pod=~\\\"$broker\\\"}*100\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Network Processor Avg Idle Percent\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"percent\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Average percentage of time request handler threads are idle\",\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":12,\"x\":12,\"y\":65},\"hiddenSeries\":false,\"id\":62,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"kafka_server_kafkarequesthandlerpool_requesthandleravgidle_percent{namespace=\\\"$namespace\\\",pod=~\\\"$broker\\\"}*100\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Request Handler Avg Idle Percent\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"percent\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Disk writes\",\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":8,\"x\":0,\"y\":73},\"hiddenSeries\":false,\"id\":104,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(irate(kafka_server_kafkaserver_linux_disk_write_bytes{namespace=\\\"$namespace\\\",pod=~\\\"$broker\\\"}[1m]))by(pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Disk Writes\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"bytes\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Disk reads\",\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":8,\"x\":8,\"y\":73},\"hiddenSeries\":false,\"id\":105,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(irate(kafka_server_kafkaserver_linux_disk_read_bytes{namespace=\\\"$namespace\\\",pod=~\\\"$broker\\\"}[1m]))by(pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Disk Reads\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"bytes\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Disk reads\",\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":8,\"x\":16,\"y\":73},\"hiddenSeries\":false,\"id\":106,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":true,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(kafka_server_socket_server_metrics_connection_count{namespace=\\\"$namespace\\\",pod=~\\\"$broker\\\"}) by (pod, listener)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{listener}}-{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Connection Count per Listener\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"none\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"collapsed\":false,\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":81},\"id\":121,\"panels\":[],\"title\":\"JVM\",\"type\":\"row\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":12,\"x\":0,\"y\":82},\"hiddenSeries\":false,\"id\":93,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[{\"$$hashKey\":\"object:1367\",\"alias\":\"{{pod}} useage percent\",\"lines\":true,\"yaxis\":1}],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(jvm_memory_bytes_used{namespace=\\\"$namespace\\\",container=\\\"kafka\\\",pod=~\\\"$broker\\\"}) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}} useage\",\"range\":true,\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"sum(jvm_memory_bytes_max{namespace=\\\"$namespace\\\",container=\\\"kafka\\\",pod=~\\\"$broker\\\"})by(pod)\",\"hide\":true,\"legendFormat\":\"{{pod}} limit\",\"range\":true,\"refId\":\"B\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"JVM Memory Used\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1324\",\"format\":\"decbytes\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1325\",\"format\":\"percent\",\"label\":\"Usage Percentage\",\"logBase\":1,\"max\":\"1\",\"min\":\"0\",\"show\":false}],\"yaxis\":{\"align\":true}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"JVM thread count\",\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":6,\"x\":12,\"y\":82},\"hiddenSeries\":false,\"id\":126,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(jvm_classes_currently_loaded{namespace=\\\"$namespace\\\",container=\\\"kafka\\\",pod=~\\\"$broker\\\"})by(pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"JVM Class loaded\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1665\",\"format\":\"short\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1666\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"JVM thread count\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":6,\"x\":18,\"y\":82},\"id\":125,\"links\":[],\"options\":{\"colorMode\":\"value\",\"graphMode\":\"area\",\"justifyMode\":\"auto\",\"orientation\":\"auto\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"/^version$/\",\"values\":false},\"showPercentChange\":false,\"textMode\":\"auto\",\"wideLayout\":true},\"pluginVersion\":\"10.3.3\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"jvm_info{namespace=\\\"$namespace\\\",container=\\\"kafka\\\",pod=~\\\"$broker\\\"}\",\"format\":\"table\",\"instant\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"Java version\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"JVM thread count\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":6,\"x\":18,\"y\":86},\"id\":124,\"links\":[],\"options\":{\"colorMode\":\"value\",\"graphMode\":\"area\",\"justifyMode\":\"auto\",\"orientation\":\"auto\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"/^jdk$/\",\"values\":false},\"showPercentChange\":false,\"textMode\":\"auto\",\"wideLayout\":true},\"pluginVersion\":\"10.3.3\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"label_join(jvm_info{namespace=\\\"$namespace\\\",container=\\\"kafka\\\",pod=~\\\"$broker\\\"}, \\\"jdk\\\", \\\", \\\", \\\"vendor\\\", \\\"runtime\\\")\",\"format\":\"table\",\"instant\":true,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":false,\"refId\":\"A\"}],\"title\":\"JVM runtime\",\"type\":\"stat\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":6,\"x\":0,\"y\":90},\"hiddenSeries\":false,\"id\":122,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(jvm_memory_bytes_used{namespace=\\\"$namespace\\\",container=\\\"kafka\\\",pod=~\\\"$broker\\\",area=\\\"heap\\\"}) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"\",\"hide\":false,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"B\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Heap Memory Used\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1271\",\"format\":\"decbytes\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1272\",\"format\":\"percent\",\"logBase\":1,\"max\":\"1\",\"min\":\"0\",\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":6,\"x\":6,\"y\":90},\"hiddenSeries\":false,\"id\":123,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":false,\"max\":true,\"min\":true,\"rightSide\":false,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(jvm_memory_bytes_used{namespace=\\\"$namespace\\\",container=\\\"kafka\\\",pod=~\\\"$broker\\\",area=\\\"nonheap\\\"}) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"NonHeap Memory Used\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:163\",\"decimals\":2,\"format\":\"decbytes\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:164\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"JVM thread count\",\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":6,\"x\":12,\"y\":90},\"hiddenSeries\":false,\"id\":116,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(jvm_threads_current{namespace=\\\"$namespace\\\",container=\\\"kafka\\\",pod=~\\\"$broker\\\"})by(pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"JVM Thread Count\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:294\",\"format\":\"short\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:295\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"JVM thread count\",\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":6,\"x\":18,\"y\":90},\"hiddenSeries\":false,\"id\":127,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"sum(jvm_threads_state{namespace=\\\"$namespace\\\",container=\\\"kafka\\\",pod=~\\\"$broker\\\"})by(pod,state)\",\"format\":\"time_series\",\"instant\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}} {{state}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"JVM Thread State\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1730\",\"format\":\"short\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1731\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":0,\"y\":98},\"hiddenSeries\":false,\"id\":95,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(increase(jvm_gc_collection_seconds_count{namespace=\\\"$namespace\\\",container=\\\"kafka\\\",pod=~\\\"$broker\\\"}[1m])) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}} {{gc}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"JVM GC Count\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1535\",\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1536\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":12,\"y\":98},\"hiddenSeries\":false,\"id\":113,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(increase(jvm_gc_collection_seconds_sum{namespace=\\\"$namespace\\\",container=\\\"kafka\\\",pod=~\\\"$broker\\\"}[1m])) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}} {{gc}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"JVM GC Time\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"ms\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":6,\"x\":0,\"y\":105},\"hiddenSeries\":false,\"id\":97,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"sum(increase(jvm_gc_collection_seconds_count{namespace=\\\"$namespace\\\",container=\\\"kafka\\\",pod=~\\\"$broker\\\",gc=~\\\"Copy|G1 Young Generation\\\"}[1m])) by (pod)\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}} {{gc}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Young GC Count\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1474\",\"format\":\"short\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1475\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":6,\"x\":6,\"y\":105},\"hiddenSeries\":false,\"id\":114,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"sum(increase(jvm_gc_collection_seconds_count{namespace=\\\"$namespace\\\",container=\\\"kafka\\\",pod=~\\\"$broker\\\",gc=~\\\"MarkSweepCompact|G1 Old.*\\\"}[1m])) by (pod)\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}} {{gc}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Old GC Count\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"short\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":6,\"x\":12,\"y\":105},\"hiddenSeries\":false,\"id\":117,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(increase(jvm_gc_collection_seconds_sum{namespace=\\\"$namespace\\\",container=\\\"kafka\\\",pod=~\\\"$broker\\\",gc=~\\\"Copy|G1 Young Generation\\\"}[1m])) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}} {{gc}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Young GC Time\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:163\",\"format\":\"ms\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:164\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":6,\"x\":18,\"y\":105},\"hiddenSeries\":false,\"id\":115,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(increase(jvm_gc_collection_seconds_sum{namespace=\\\"$namespace\\\",container=\\\"kafka\\\",pod=~\\\"$broker\\\",gc=~\\\"MarkSweepCompact|G1 Old Generation\\\"}[1m])) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}} {{gc}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Old GC Time\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"ms\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}}],\"refresh\":\"1m\",\"schemaVersion\":39,\"tags\":[\"Kafka\",\"broker\",\"topic\"],\"templating\":{\"list\":[{\"current\":{\"selected\":false,\"text\":\"Prometheus\",\"value\":\"prometheus\"},\"hide\":0,\"includeAll\":false,\"label\":\"datasource\",\"multi\":false,\"name\":\"datasource\",\"options\":[],\"query\":\"prometheus\",\"queryValue\":\"\",\"refresh\":1,\"regex\":\"\",\"skipUrlSync\":false,\"type\":\"datasource\"},{\"current\":{\"selected\":false,\"text\":\"kdp-data\",\"value\":\"kdp-data\"},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"definition\":\"query_result(kafka_server_replicamanager_leadercount)\",\"hide\":0,\"includeAll\":false,\"label\":\"Namespace\",\"multi\":false,\"name\":\"namespace\",\"options\":[],\"query\":{\"query\":\"query_result(kafka_server_replicamanager_leadercount)\",\"refId\":\"StandardVariableQuery\"},\"refresh\":1,\"regex\":\"/.*namespace=\\\"([^\\\"]+).*/\",\"skipUrlSync\":false,\"sort\":1,\"tagValuesQuery\":\"\",\"tagsQuery\":\"\",\"type\":\"query\",\"useTags\":false},{\"current\":{\"selected\":false,\"text\":\"kafka-3-cluster\",\"value\":\"kafka-3-cluster\"},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"definition\":\"query_result(kafka_server_replicamanager_leadercount{namespace=\\\"$namespace\\\"})\",\"hide\":0,\"includeAll\":false,\"label\":\"Cluster Name\",\"multi\":false,\"name\":\"strimzi_cluster_name\",\"options\":[],\"query\":{\"query\":\"query_result(kafka_server_replicamanager_leadercount{namespace=\\\"$namespace\\\"})\",\"refId\":\"StandardVariableQuery\"},\"refresh\":1,\"regex\":\"/.*pod=\\\"([^\\\"]*)-kafka-*.*/\",\"skipUrlSync\":false,\"sort\":0,\"tagValuesQuery\":\"\",\"tagsQuery\":\"\",\"type\":\"query\",\"useTags\":false},{\"allValue\":\".*\",\"current\":{\"selected\":false,\"text\":\"All\",\"value\":\"$__all\"},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"definition\":\"query_result(kafka_server_replicamanager_leadercount{namespace=\\\"$namespace\\\",pod=~\\\"$strimzi_cluster_name.*\\\"})\",\"hide\":0,\"includeAll\":true,\"label\":\"Broker\",\"multi\":false,\"name\":\"broker\",\"options\":[],\"query\":{\"query\":\"query_result(kafka_server_replicamanager_leadercount{namespace=\\\"$namespace\\\",pod=~\\\"$strimzi_cluster_name.*\\\"})\",\"refId\":\"StandardVariableQuery\"},\"refresh\":1,\"regex\":\"/.*pod=\\\"([^\\\"]+).*/\",\"skipUrlSync\":false,\"sort\":1,\"tagValuesQuery\":\"\",\"tagsQuery\":\"\",\"type\":\"query\",\"useTags\":false},{\"allValue\":\".+\",\"current\":{\"selected\":false,\"text\":\"All\",\"value\":\"$__all\"},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"definition\":\"query_result(kafka_cluster_partition_replicascount{namespace=\\\"$namespace\\\",pod=~\\\"$broker\\\"})\",\"hide\":0,\"includeAll\":true,\"label\":\"Topic\",\"multi\":false,\"name\":\"kafka_topic\",\"options\":[],\"query\":{\"query\":\"query_result(kafka_cluster_partition_replicascount{namespace=\\\"$namespace\\\",pod=~\\\"$broker\\\"})\",\"refId\":\"StandardVariableQuery\"},\"refresh\":1,\"regex\":\"/.*topic=\\\"([^\\\"]*).*/\",\"skipUrlSync\":false,\"sort\":0,\"tagValuesQuery\":\"\",\"tagsQuery\":\"\",\"type\":\"query\",\"useTags\":false},{\"allValue\":\".*\",\"current\":{\"selected\":true,\"text\":[\"All\"],\"value\":[\"$__all\"]},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"definition\":\"query_result(kafka_log_log_size{namespace=\\\"$namespace\\\",pod=~\\\"$broker\\\",topic=~\\\"$kafka_topic\\\"})\",\"hide\":0,\"includeAll\":true,\"label\":\"Partition\",\"multi\":true,\"name\":\"partition\",\"options\":[],\"query\":{\"query\":\"query_result(kafka_log_log_size{namespace=\\\"$namespace\\\",pod=~\\\"$broker\\\",topic=~\\\"$kafka_topic\\\"})\",\"refId\":\"StandardVariableQuery\"},\"refresh\":1,\"regex\":\"/.*partition=\\\"([^\\\"]*).*/\",\"skipUrlSync\":false,\"sort\":3,\"tagValuesQuery\":\"\",\"tagsQuery\":\"\",\"type\":\"query\",\"useTags\":false}]},\"time\":{\"from\":\"now-1h\",\"to\":\"now\"},\"timepicker\":{\"refresh_intervals\":[\"5s\",\"10s\",\"30s\",\"1m\",\"5m\",\"15m\",\"30m\",\"1h\",\"2h\",\"1d\"],\"time_options\":[\"5m\",\"15m\",\"1h\",\"6h\",\"12h\",\"24h\",\"2d\",\"7d\",\"30d\"]},\"timezone\":\"\",\"title\":\"KDP Kafka Dashboard\",\"uid\":\"kdpKafkaDashboard2023\",\"version\":1,\"weekStart\":\"\"}"
								}
								"labels": {
									"app":               "grafana"
									"grafana_dashboard": "1"
								}
							}
							"type": "bdos-grafana-dashboard"
						},
					]
				},
			]
			"policies": [
				{
					"name": "shared-resource"
					"properties": {
						"rules": [
							{
								"selector": {
									"traitTypes": [
										"bdos-grafana-dashboard",
									]
								}
							},
						]
					}
					"type": "shared-resource"
				},
			]
		}
	}
	parameter: {
		// +minimum=1
		// +ui:description=副本数
		// +ui:order=1
		replicas: *3 | int
		// +ui:description=资源规格
		// +ui:order=2
		resources: {
			// +ui:description=预留
			// +ui:order=1
			requests: {
				// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
				// +ui:order=1
				// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
				cpu: *"0.5" | string
				// +pattern=^[1-9]\d*(Mi|Gi)$
				// +ui:order=2
				// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
				memory: *"2048Mi" | string
			}
			// +ui:description=限制
			// +ui:order=2
			limits: {
				// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
				// +ui:order=1
				// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
				cpu: *"2" | string
				// +pattern=^[1-9]\d*(Mi|Gi)$
				// +ui:order=2
				// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
				memory: *"2048Mi" | string
			}
		}
		// +ui:description=存储大小
		// +ui:order=3
		storage: {
			// +pattern=^([1-9]\d*)(Ti|Gi|Mi)$
			// +ui:order=1
			// +err:options={"pattern":"请输入正确的存储格式，如1024Mi, 1Gi, 1Ti"}
			size: *"10Gi" | string
		}
		// +ui:description=kafka端口设置
		// +ui:order=4
		listeners: {
			// +ui:description=端口类型。注意：发布后请不要更新修改，请做好提前规划。
			// +ui:order=1
			"type": *"internal" | "nodeport"
			// +ui:description=端口号
			// +ui:order=2
			// +ui:options={"disabled":true}
			"port": *9092 | int
			// +minimum=1
			// +maximum=65500
			// +ui:description=nodeport端口号。注意：发布后请不要更新修改，请做好提前规划。
			// +ui:order=3
			// +ui:hidden={{rootFormData.listeners.type != "nodeport"}}
			"nodePort": *31091 | int
		}
		// +ui:description=kafka监控
		// +ui:order=5
		metrics: {
			// +ui:description=开启监控
			enable: *true | bool
		}
		// +ui:description=kafka配置
		// +ui:order=5
		config: *{
			"auto.create.topics.enable":                true
			"delete.topic.enable":                      true
			"default.replication.factor":               1
			"log.retention.bytes":                      -1
			"log.retention.hours":                      168
		} | {...}
		// +ui:description=kafka依赖zookeeper配置
		// +ui:order=6
		zookeeper: {
			// +minimum=1
			// +ui:description=zk副本数
			// +ui:order=2
			replicas: *3 | int
			// +ui:description=zk资源规格
			// +ui:order=3
			resources: {
				// +ui:description=预留
				// +ui:order=1
				requests: {
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +ui:order=1
					// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
					cpu: *"0.5" | string
					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +ui:order=2
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					memory: *"2048Mi" | string
				}
				// +ui:description=限制
				// +ui:order=2
				limits: {
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +ui:order=1
					// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
					cpu: *"2" | string
					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +ui:order=2
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					memory: *"2048Mi" | string
				}
			}
			// +ui:description=zk存储大小
			// +ui:order=4
			storage: {
				// +pattern=^([1-9]\d*)(Ti|Gi|Mi)$
				// +ui:order=1
				// +err:options={"pattern":"请输入正确的存储格式，如1024Mi, 1Gi, 1Ti"}
				size: *"5Gi" | string
			}
		}
		// +ui:description=镜像版本
		// +ui:order=10001
		// +ui:options={"disabled":true}
		image: *"kafka/kafka:v1.0.0-0.34.0-3-kafka-3.4.1" | string
	}
}
