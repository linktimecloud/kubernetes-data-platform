"zookeeper": {
	annotations: {}
	labels: {}
	attributes: {
		"dynamicParameterMeta": [

		]
		apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "Application"
				type:       "zookeeper"
			}
		}
	}
	description: "zookeeper xdefinition"
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
						"chart":           "zookeeper"
						"version":         parameter.chartVersion
						"url":             context.helm_repo_url
						"repoType":        "helm"
						"releaseName":     context.name
						"targetNamespace": context.namespace
						"values": {
							"image": {
								"tag": parameter.imageTag
							}
							"replicaCount": parameter.replicaCount
							"resources":    parameter.resources
							"heapSize":     parameter.heapSize
							"log4jProp":    "INFO, ROLLINGFILE"
							"logLevel":     "INFO"
							"metrics": {
								"enabled": true
							}
							"global": {
								"storageClass":  context["storage_config.storage_class_mapping.local_disk"]
								"imageRegistry": context.docker_registry
							}
							"persistence": {
								"enabled": true
								"size":    "8Gi"
							}
							"autopurge": parameter.autopurge
							"livenessProbe": {
								"enabled": false
							}
							"readinessProbe": {
								"enabled": false
							}
							"customLivenessProbe": {
								"exec": {
									"command": [
										"/bin/bash",
										"-c",
										"curl -s -m 2 http://localhost:8080/commands/ruok | grep ruok",
									]
								}
								"initialDelaySeconds": 30
								"periodSeconds":       10
								"timeoutSeconds":      5
								"successThreshold":    1
								"failureThreshold":    6
							}
							"customReadinessProbe": {
								"exec": {
									"command": [
										"/bin/bash",
										"-c",
										"curl -s -m 2 http://localhost:8080/commands/ruok | grep error | grep null",
									]
								}
								"initialDelaySeconds": 5
								"periodSeconds":       10
								"timeoutSeconds":      5
								"successThreshold":    1
								"failureThreshold":    6
							}
							"extraVolumeMounts": [
								{
									"mountPath": "/opt/bitnami/zookeeper/logs"
									"name":      "logs"
								},
							]
							"extraVolumes": [
								{
									"emptyDir": {}
									"name": "logs"
								},
								{
									"configMap": {
										"defaultMode": 420
										"name":        "promtail-conf"
									}
									"name": "promtail-conf"
								},
							]
							"sidecars": [
								{
									"name": "logs-promtail-sidecar"
									"env": [
										{
											"name": "LOKI_PUSH_URL"
											"valueFrom": {
												"configMapKeyRef": {
													"key":  "LOKI_PUSH_URL"
													"name": "promtail-args"
												}
											}
										},
										{
											"name": "POD_NAME"
											"valueFrom": {
												"fieldRef": {
													"apiVersion": "v1"
													"fieldPath":  "metadata.name"
												}
											}
										},
										{
											"name":  "PROMTAIL_PORT"
											"value": "3101"
										},
										{
											"name":  "PROMTAIL_NAMESPACE"
											"value": context.namespace
										},
										{
											"name":  "PROMTAIL_APPNAME"
											"value": context.name
										},
										{
											"name":  "PROMTAIL_LOG_PATH"
											"value": "/var/log/\(context.namespace)-\(context.name)/**"
										},
									]
									"image": "\(context.docker_registry)/grafana/promtail:2.5.0"
									"args": [
										"-config.file=/etc/promtail/config.yaml",
										"-config.expand-env=true",
									]
									"resources": {
										"limits": {
											"cpu":    "100m"
											"memory": "128Mi"
										}
										"requests": {
											"cpu":    "100m"
											"memory": "128Mi"
										}
									}
									"volumeMounts": [
										{
											"mountPath": "/var/log/\(context.namespace)-\(context.name)"
											"name":      "logs"
										},
										{
											"mountPath": "/etc/promtail"
											"name":      "promtail-conf"
										},
									]
								},
							]
							"affinity": {
								"podAntiAffinity": {
									"requiredDuringSchedulingIgnoredDuringExecution": [
										{
											"labelSelector": {
												"matchExpressions": [
													{
														"key":      "app.kubernetes.io/instance"
														"operator": "In"
														"values": [
															context.name,
														]
													},
												]
											}
											"topologyKey": "kubernetes.io/hostname"
										},
									]
								}
							}
						}
					}
					"traits": [
						{
							"type": "bdos-logtail"
							"properties": {
								"name": "logs"
								"path": "/var/log/\(context.namespace)-\(context.name)"
								"promtail": {
									"listenPort": 13101
								}
							}
						},
						{
							"type": "bdos-monitor"
							"properties": {
								"monitortype": "pod"
								"endpoints": [
									{
										"port":     9141
										"portName": "metrics"
									},
								]
								"matchLabels": {
									"app.kubernetes.io/instance": context.name
								}
							}
						},
						{
							"type": "bdos-prometheus-rules"
							"properties": {
								"labels": {
									"prometheus": "k8s"
									"role":       "alert-rules"
									"release":    "prometheus"
								}
								"groups": [
									{
										"name": "zookeeper.rules"
										"rules": [
											{
												"alert":    "zookeeper open file descriptor percentage is over 90%"
												"expr":     "open_file_descriptor_count/max_file_descriptor_count > 0.9"
												"duration": "10s"
												"labels": {
													"severity": "high"
												}
												"annotations": {
													"summary":     "{{$labels.namespace}}/{{ $labels.pod }},zookeeper open file descriptor percentage is over 90%"
													"description": "{{$labels.namespace}}/{{ $labels.pod }},zookeeper open file descriptor percentage is over 90%, value is {{ $value }}"
												}
											},
											{
												"alert":    "zookeeper leader election happened"
												"expr":     "increase(election_time_count[1m]) > 0"
												"duration": "10s"
												"labels": {
													"severity": "high"
												}
												"annotations": {
													"summary":     "{{$labels.namespace}}/{{ $labels.pod }}, zookeeper leader election happened"
													"description": "{{$labels.namespace}}/{{ $labels.pod }}, zookeeper leader election happened"
												}
											},
											{
												"alert":    "zookeeper server open too many sessions"
												"expr":     "global_sessions > 200"
												"duration": "10s"
												"labels": {
													"severity": "high"
												}
												"annotations": {
													"summary":     "{{$labels.namespace}}/{{ $labels.pod }},zookeeper server open too many sessions"
													"description": "{{$labels.namespace}}/{{ $labels.pod }},zookeeper server open too many sessions, value is {{ $value }}"
												}
											},
											{
												"alert":    "zookeeper cluster too manager leaders"
												"expr":     "count(leader_uptime) > 1"
												"duration": "60s"
												"labels": {
													"severity": "high"
												}
												"annotations": {
													"summary":     "{{$labels.namespace}}/{{ $labels.job }},zookeeper cluster too manager leaders"
													"description": "{{$labels.namespace}}/{{ $labels.job }},zookeeper cluster too manager leaders, value is {{ $value }}"
												}
											},
										]
									},
								]
							}
						},
						{
							"type": "bdos-grafana-dashboard"
							"properties": {
								"labels": {
									"app":               "grafana"
									"grafana_dashboard": "1"
								}
								"dashboard_data": {
									"zookeeper-dashboard.json": "{\"annotations\":{\"list\":[{\"builtIn\":1,\"datasource\":{\"type\":\"datasource\",\"uid\":\"grafana\"},\"enable\":true,\"hide\":true,\"iconColor\":\"rgba(0, 211, 255, 1)\",\"name\":\"Annotations & Alerts\",\"target\":{\"limit\":100,\"matchAny\":false,\"tags\":[],\"type\":\"dashboard\"},\"type\":\"dashboard\"}]},\"description\":\"ZooKeeper Dashboard for Prometheus metrics scraper\",\"editable\":true,\"fiscalYearStartMonth\":0,\"gnetId\":10465,\"graphTooltip\":0,\"id\":391,\"links\":[],\"liveNow\":false,\"panels\":[{\"collapsed\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":0},\"id\":14,\"panels\":[],\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"refId\":\"A\"}],\"title\":\"Overview\",\"type\":\"row\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"semi-dark-red\",\"value\":null},{\"color\":\"semi-dark-red\",\"value\":1},{\"color\":\"semi-dark-yellow\",\"value\":2},{\"color\":\"semi-dark-green\",\"value\":3}]}},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":4,\"x\":0,\"y\":1},\"id\":162,\"options\":{\"colorMode\":\"none\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"auto\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"count(uptime{namespace=\\\"$namespace\\\",pod=~\\\"$cluster-.*\\\"})\",\"refId\":\"A\"}],\"title\":\"Active Node\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"semi-dark-red\",\"value\":1},{\"color\":\"semi-dark-yellow\",\"value\":2},{\"color\":\"semi-dark-green\",\"value\":3}]}},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":4,\"x\":4,\"y\":1},\"id\":163,\"options\":{\"colorMode\":\"none\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"auto\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"/^pod$/\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"leader_uptime{namespace=\\\"$namespace\\\",pod=~\\\"$cluster-.*\\\"}\",\"format\":\"table\",\"instant\":true,\"range\":false,\"refId\":\"A\"}],\"title\":\"Leader\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"semi-dark-green\",\"value\":null},{\"color\":\"semi-dark-red\",\"value\":1},{\"color\":\"semi-dark-green\",\"value\":2}]}},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":4,\"x\":8,\"y\":1},\"id\":166,\"options\":{\"colorMode\":\"none\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"auto\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"learners{namespace=\\\"$namespace\\\",pod=~\\\"$cluster-.*\\\"}\",\"instant\":true,\"range\":false,\"refId\":\"A\"}],\"title\":\"Learner（follower+observer）\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"semi-dark-green\",\"value\":null},{\"color\":\"semi-dark-red\",\"value\":1}]}},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":4,\"x\":12,\"y\":1},\"id\":167,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"area\",\"justifyMode\":\"auto\",\"orientation\":\"auto\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"sum(quorum_size{namespace=\\\"$namespace\\\",pod=~\\\"$cluster-.*\\\"}-synced_followers{namespace=\\\"$namespace\\\",pod=~\\\"$cluster-.*\\\"}-1)\",\"instant\":false,\"range\":true,\"refId\":\"A\"}],\"title\":\"Out of sync Followers\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[],\"noValue\":\"0\",\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"semi-dark-green\",\"value\":null},{\"color\":\"semi-dark-red\",\"value\":1}]}},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":4,\"x\":16,\"y\":1},\"id\":169,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"area\",\"justifyMode\":\"auto\",\"orientation\":\"auto\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"sum(learners{namespace=\\\"$namespace\\\",pod=~\\\"$cluster-.*\\\"}+1-quorum_size{namespace=\\\"$namespace\\\",pod=~\\\"$cluster-.*\\\"}-synced_observers{namespace=\\\"$namespace\\\",pod=~\\\"$cluster-.*\\\"}) >= 0\",\"instant\":false,\"range\":true,\"refId\":\"A\"}],\"title\":\"Out of sync Observers\",\"transformations\":[{\"id\":\"reduce\",\"options\":{\"labelsToFields\":false,\"reducers\":[]}}],\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"semi-dark-green\",\"value\":null},{\"color\":\"#EAB839\",\"value\":70},{\"color\":\"semi-dark-red\",\"value\":90}]},\"unit\":\"percentunit\"},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":4,\"x\":20,\"y\":1},\"id\":170,\"options\":{\"orientation\":\"auto\",\"reduceOptions\":{\"calcs\":[\"last\"],\"fields\":\"\",\"values\":false},\"showThresholdLabels\":false,\"showThresholdMarkers\":true},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"sum(open_file_descriptor_count{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\",pod=~\\\"$cluster-.*\\\"})/sum(max_file_descriptor_count{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\",pod=~\\\"$cluster-.*\\\"})\",\"refId\":\"A\"}],\"title\":\"Open file descriptor\",\"type\":\"gauge\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":2,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":true,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":6,\"x\":0,\"y\":7},\"id\":124,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"sum(quorum_size{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\"})by(pod)\",\"format\":\"time_series\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}} configed quorum size\",\"range\":true,\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"sum(learners{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\"})by(pod)\",\"format\":\"time_series\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}(leader) learners\",\"range\":true,\"refId\":\"B\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"sum(synced_non_voting_followers{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\"})by(pod)\",\"format\":\"time_series\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}(leader)  synced_non_voting_followers\",\"range\":true,\"refId\":\"C\"}],\"title\":\"server info\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineStyle\":{\"fill\":\"solid\"},\"lineWidth\":2,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":true,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":6,\"x\":6,\"y\":7},\"id\":70,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"election_time{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\"}\",\"format\":\"time_series\",\"hide\":true,\"intervalFactor\":2,\"legendFormat\":\"{{pod}} election_time\",\"range\":true,\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"sum(increase(election_time_count{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\"}[1m]))by(pod)\",\"format\":\"time_series\",\"hide\":false,\"intervalFactor\":2,\"legendFormat\":\"{{pod}} election\",\"range\":true,\"refId\":\"B\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"election_time_sum{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\"}\",\"format\":\"time_series\",\"hide\":true,\"intervalFactor\":2,\"legendFormat\":\"{{pod}} election_time_sum\",\"range\":true,\"refId\":\"C\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"election_time_sum{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\"}/election_time_count{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\"}\",\"format\":\"time_series\",\"hide\":true,\"intervalFactor\":2,\"legendFormat\":\"{{pod}} election_avg_time\",\"range\":true,\"refId\":\"D\"}],\"title\":\"election\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":2,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":true,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":6,\"x\":12,\"y\":7},\"id\":4,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"sum(znode_count{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\"})by(pod)\",\"format\":\"time_series\",\"instant\":false,\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"title\":\"znode_count\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":2,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":true,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":6,\"x\":18,\"y\":7},\"id\":28,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"sum(ephemerals_count{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\"})by(pod)\",\"format\":\"time_series\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"ephemerals_count\",\"type\":\"timeseries\"},{\"collapsed\":false,\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":15},\"id\":172,\"panels\":[],\"title\":\"Network\",\"type\":\"row\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":2,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":true,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":7,\"w\":12,\"x\":0,\"y\":16},\"id\":90,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"max\",\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"sum(irate(packets_received{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\"}[1m]))by(pod)\",\"format\":\"time_series\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"packets received per second\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":2,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":true,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":7,\"w\":12,\"x\":12,\"y\":16},\"id\":56,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"max\",\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"sum(irate(packets_sent{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\"}[1m]))by(pod)\",\"format\":\"time_series\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"packets sent per second\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":2,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":true,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":12,\"x\":0,\"y\":23},\"id\":100,\"interval\":\"\",\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"min\",\"max\",\"last\"],\"displayMode\":\"table\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"max_latency{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\"}\",\"format\":\"time_series\",\"hide\":true,\"intervalFactor\":2,\"legendFormat\":\"{{pod}} max_latency\",\"range\":true,\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"min_latency{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\"}\",\"format\":\"time_series\",\"hide\":true,\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}} min_latency\",\"range\":true,\"refId\":\"B\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"sum(avg_latency{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\"})by(pod)\",\"format\":\"time_series\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}} avg_latency\",\"range\":true,\"refId\":\"C\"}],\"title\":\"latency avg\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":2,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":true,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"ms\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":12,\"x\":12,\"y\":23},\"id\":134,\"links\":[],\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"sum(proposal_latency{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\", quantile=~\\\"0.99\\\"})by(pod,quantile) >= 0\",\"format\":\"time_series\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}} proposal_latency-{{quantile}}\",\"range\":true,\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"proposal_latency_count{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\"}\",\"format\":\"time_series\",\"hide\":true,\"intervalFactor\":2,\"legendFormat\":\"{{pod}} proposal_latency_count\",\"range\":true,\"refId\":\"B\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"proposal_latency{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\"}\",\"format\":\"time_series\",\"hide\":true,\"intervalFactor\":2,\"legendFormat\":\"{{pod}} proposal_latency_sum\",\"range\":true,\"refId\":\"C\"}],\"title\":\"proposal_latency\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":2,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":true,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":8,\"x\":0,\"y\":31},\"id\":66,\"links\":[],\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"sum(outstanding_requests{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\"})by(pod)\",\"format\":\"time_series\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"outstanding_requests\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":2,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":true,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":8,\"x\":8,\"y\":31},\"id\":132,\"links\":[],\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"sum(approximate_data_size{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\"})by(pod)\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"approximate_data_size\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":2,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"decbytes\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":8,\"x\":16,\"y\":31},\"id\":146,\"links\":[],\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"sum(irate(bytes_received_count{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\"}[1m]))by(pod)\",\"format\":\"time_series\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"bytes_received_count\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":11,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineStyle\":{\"fill\":\"solid\"},\"lineWidth\":2,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]}},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":8,\"x\":0,\"y\":39},\"id\":48,\"links\":[],\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"sum(global_sessions{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\"})by(pod)\",\"format\":\"time_series\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"global_sessions\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":2,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":true,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":8,\"x\":8,\"y\":39},\"id\":128,\"links\":[],\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"sum(increase(connection_drop_count{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\"}[1m]))by(pod)\",\"format\":\"time_series\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"connection drop per minute\",\"type\":\"timeseries\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":8,\"x\":16,\"y\":39},\"hiddenSeries\":false,\"id\":86,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":2,\"links\":[],\"nullPointMode\":\"connected\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":2,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"sum(connection_rejected{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\"})by(pod)\",\"format\":\"time_series\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"connection rejected\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1306\",\"format\":\"short\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1307\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"collapsed\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":47},\"id\":82,\"panels\":[],\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"refId\":\"A\"}],\"title\":\"Commit\",\"type\":\"row\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"unit\":\"ms\"},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":12,\"x\":0,\"y\":48},\"hiddenSeries\":false,\"id\":74,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":2,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":2,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"sum(server_write_committed_time_ms{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\",quantile=\\\"0.99\\\"})by(pod,quantile)\",\"format\":\"time_series\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}} server_write_committed_time_ms-{{quantile}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"server_write_committed_time\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:2239\",\"format\":\"ms\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:2240\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"unit\":\"ms\"},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":12,\"x\":12,\"y\":48},\"hiddenSeries\":false,\"id\":173,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":2,\"links\":[],\"nullPointMode\":\"connected\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":2,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"sum(local_write_committed_time_ms{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\",quantile=\\\"0.99\\\"})by(pod,quantile)\",\"format\":\"time_series\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}} local_write_committed_time_ms-{{quantile}}\",\"range\":true,\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"local_write_committed_time_ms_count{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\"}\",\"format\":\"time_series\",\"hide\":true,\"intervalFactor\":2,\"legendFormat\":\"{{pod}} local_write_committed_time_ms_count\",\"range\":true,\"refId\":\"B\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"local_write_committed_time_ms_sum{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\"}\",\"format\":\"time_series\",\"hide\":true,\"intervalFactor\":2,\"legendFormat\":\"{{pod}} local_write_committed_time_ms_sum\",\"range\":true,\"refId\":\"C\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"local_write_committed_time\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:2154\",\"format\":\"ms\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:2155\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":12,\"x\":0,\"y\":56},\"hiddenSeries\":false,\"id\":148,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":2,\"links\":[],\"nullPointMode\":\"connected\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":2,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"sum(irate(commit_count{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\"}[1m]))by(pod)\",\"format\":\"time_series\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"commit_count（per second）\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:2749\",\"format\":\"short\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:2750\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":12,\"x\":12,\"y\":56},\"hiddenSeries\":false,\"id\":154,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":2,\"links\":[],\"nullPointMode\":\"connected\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":2,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"sum(irate(proposal_count{container=~\\\".*zookeeper\\\", namespace=\\\"$namespace\\\", pod=~\\\"$pod\\\",pod=~\\\"$cluster-[0-9]+\\\"}[1m]))by(pod)\",\"format\":\"time_series\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"proposal_count（per second）\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:2834\",\"format\":\"short\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:2835\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}}],\"refresh\":\"1m\",\"schemaVersion\":36,\"style\":\"dark\",\"tags\":[],\"templating\":{\"list\":[{\"current\":{\"selected\":false,\"text\":\"Prometheus\",\"value\":\"Prometheus\"},\"hide\":0,\"includeAll\":false,\"multi\":false,\"name\":\"datasource\",\"options\":[],\"query\":\"prometheus\",\"queryValue\":\"\",\"refresh\":1,\"regex\":\"\",\"skipUrlSync\":false,\"type\":\"datasource\"},{\"current\":{\"selected\":true,\"text\":\"admin\",\"value\":\"admin\"},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"definition\":\"label_values(ephemerals_count{container=~\\\".*zookeeper\\\"}, namespace)\",\"hide\":0,\"includeAll\":false,\"multi\":false,\"name\":\"namespace\",\"options\":[],\"query\":{\"query\":\"label_values(ephemerals_count{container=~\\\".*zookeeper\\\"}, namespace)\",\"refId\":\"StandardVariableQuery\"},\"refresh\":1,\"regex\":\"\",\"skipUrlSync\":false,\"sort\":1,\"type\":\"query\"},{\"current\":{\"selected\":false,\"text\":\"zookeeper\",\"value\":\"zookeeper\"},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"definition\":\"label_values(ephemerals_count{container=~\\\".*zookeeper\\\",namespace=\\\"$namespace\\\"}, pod)\",\"hide\":0,\"includeAll\":false,\"label\":\"Cluster\",\"multi\":false,\"name\":\"cluster\",\"options\":[],\"query\":{\"query\":\"label_values(ephemerals_count{container=~\\\".*zookeeper\\\",namespace=\\\"$namespace\\\"}, pod)\",\"refId\":\"StandardVariableQuery\"},\"refresh\":1,\"regex\":\"/(.*)-.*/\",\"skipUrlSync\":false,\"sort\":0,\"type\":\"query\"},{\"allValue\":\".*\",\"current\":{\"selected\":false,\"text\":\"All\",\"value\":\"$__all\"},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"definition\":\"label_values(ephemerals_count{container=~\\\".*zookeeper\\\",namespace=\\\"$namespace\\\",pod=~\\\"$cluster-.*\\\"}, pod)\",\"hide\":0,\"includeAll\":true,\"label\":\"pod\",\"multi\":false,\"name\":\"pod\",\"options\":[],\"query\":{\"query\":\"label_values(ephemerals_count{container=~\\\".*zookeeper\\\",namespace=\\\"$namespace\\\",pod=~\\\"$cluster-.*\\\"}, pod)\",\"refId\":\"StandardVariableQuery\"},\"refresh\":2,\"regex\":\"\",\"skipUrlSync\":false,\"sort\":1,\"type\":\"query\"}]},\"time\":{\"from\":\"now-1h\",\"to\":\"now\"},\"timepicker\":{\"refresh_intervals\":[\"5s\",\"10s\",\"30s\",\"1m\",\"5m\",\"15m\",\"30m\",\"1h\",\"2h\",\"1d\"],\"time_options\":[\"5m\",\"15m\",\"1h\",\"6h\",\"12h\",\"24h\",\"2d\",\"7d\",\"30d\"]},\"timezone\":\"\",\"title\":\"ZooKeeper\",\"uid\":\"zookeeper\",\"version\":1,\"weekStart\":\"\"}"
								}
							}
						},
					]
				},
				{
					"name": "\(context.name)-config"
					"type": "raw"
					"properties": {
						"apiVersion": "bdc.kdp.io/v1alpha1"
						"kind":       "ContextSetting"
						"metadata": {
							"namespace": context.namespace
							"name":      "\(context.bdc)-\(context.name)"
							"annotations": {
								"setting.ctx.bdc.kdp.io/type":   "zookeeper"
								"setting.ctx.bdc.kdp.io/origin": "system"
							}
						}
						"spec": {
							"name": "zookeeper-context"
							"type": "zookeeper"
							"properties": {
								"host":     "zookeeper.\(context.namespace).svc.cluster.local:2181"
								"hostname": "zookeeper.\(context.namespace).svc.cluster.local"
								"port":     "2181"
							}
						}
					}
				},
			]
			"policies": [
				{
					"name": "shared-resource"
					"type": "shared-resource"
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
				},
			]
		}
	}
	parameter: {
		// +ui:description=副本数
		// +ui:order=3
		// +minimum=3
		replicaCount: *3 | int
		// +ui:description=资源规格
		// +ui:order=4
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
				memory: *"512Mi" | string
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
				memory: *"512Mi" | string
			}
		}
		// +ui:description=堆内存大小（单位 Mi）
		// +ui:order=5
		// +minimum=0
		heapSize: *384 | int
		// +ui:description=自动清理快照和事务日志
		// +ui:order=6
		autopurge: {
			// +ui:description=快照保留数量
			// +ui:order=1
			// +minimum=0
			snapRetainCount: *3 | int
			// +ui:description=清理周期，单位为小时。0 代表不清理。
			// +ui:order=2
			// +minimum=0
			purgeInterval: *1 | int
		}
		// +ui:description=Helm Chart 版本号
		// +ui:order=100
		// +ui:options={"disabled":true}
		chartVersion: *"7.6.2" | string
		// +ui:description=镜像版本
		// +ui:order=101
		// +ui:options={"disabled":true}
		imageTag: *"3.8.2" | string
	}
}
