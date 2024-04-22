import ("strconv")

import ("encoding/json")

"hdfs": {
	annotations: {}
	labels: {}
	attributes: {
		"dynamicParameterMeta": [
			{
				"name":        "dependencies.zookeeperQuorum"
				"type":        "ContextSetting"
				"refType":     "zookeeper"
				"refKey":      "host"
				"description": "zookeeper url"
				"required":    true
			},
		]
		apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "Application"
				type:       "hdfs"
			}
		}
	}
	description: "hdfs xdefinition"
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
						"chart":           "hdfs-k8s"
						"version":         parameter.chartVersion
						"url":             context["helm_repo_url"]
						"repoType":        "oci"
						"releaseName":     context.name
						"targetNamespace": context.namespace
						"values": {
							"global": {
								"namenodeHAEnabled":       parameter.namenode.HAEnabled
								"zookeeperQuorumOverride": parameter.dependencies.zookeeperQuorum
								"journalnodeQuorumSize":   parameter.journalnode.quorumSize
								"logsPromtailEnabled":     parameter.logsPromtailEnabled
								"dockerRegistry":          context["docker_registry"]
								"imageTag":                parameter.imageTag
								"zookeeperParentZnode":    parameter.dependencies.zookeeperParentZnode
								"jmxPort":                 54321
							}
							"hdfs-config-k8s": {
								"bdc": {
									"name": context.bdc
								}
								"customHadoopConfig": {
									"coreSite": parameter.coreSite
									"hdfsSite": parameter.hdfsSite
								}
							}
							"hdfs-namenode-k8s": {
								"resources": parameter.namenode.resources
								"maxRAMPercentage": parameter.namenode.maxRAMPercentage
								"persistence": {
									"storageClass": context["storage_config.storage_class_mapping.local_disk"]
									"size":         parameter.namenode.persistence.size
								}
								"podAnnotations": {
									"reloader.stakater.com/auto": "true"
								}
							}
							"hdfs-journalnode-k8s": {
								"resources": parameter.journalnode.resources
								"persistence": {
									"storageClass": context["storage_config.storage_class_mapping.local_disk"]
									"size":         parameter.journalnode.persistence.size
								}
								"podAnnotations": {
									"reloader.stakater.com/auto": "true"
								}
							}
							"hdfs-datanode-k8s": {
								"resources": parameter.datanode.resources
								"replicas":  parameter.datanode.replicas
								"maxRAMPercentage": parameter.datanode.maxRAMPercentage
								"persistence": {
									"storageClass": context["storage_config.storage_class_mapping.local_disk"]
									"size":         parameter.datanode.persistence.size
								}
								"podAnnotations": {
									"reloader.stakater.com/auto": "true"
								}
							}
						}
					}
					"traits": [
						{
							"type": "bdos-ingress"
							"properties": {
								"rules": [
									{
										"host": "\(context.name)-namenode-0-\(context.namespace).\(context["ingress.root_domain"])"
										"paths": [
											{
												"path":        "/"
												"servicePort": 9870
												"serviceName": "\(context.name)-namenode-0-svc"
											},
										]
									},
									{
										"host": "\(context.name)-namenode-1-\(context.namespace).\(context["ingress.root_domain"])"
										"paths": [
											{
												"path":        "/"
												"servicePort": 9870
												"serviceName": "\(context.name)-namenode-1-svc"
											},
										]
									},
								]
								"tls": [
									{
										"hosts": [
											"\(context.name)-namenode-0-\(context.namespace).\(context["ingress.root_domain"])",
											"\(context.name)-namenode-1-\(context.namespace).\(context["ingress.root_domain"])",
										]
										"tlsSecretName": context["ingress.tls_secret_name"]
									},
								]
							}
						},
						{
							"type": "bdos-monitor"
							"properties": {
								"monitortype": "pod"
								"endpoints": [
									{
										"port":     54321
										"portName": "jmx"
									},
								]
								"matchLabels": {
									"hdfs-metrics": "true"
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
										"name": "\(context.namespace)-\(context.name).rules"
										"rules": [
											{
												"alert":    "\(context.namespace)-\(context.name)-NamenodePodNotReady"
												"expr":     "min_over_time(sum by(namespace, pod, phase) (kube_pod_status_phase{phase=~\"Pending|Unknown|Failed\",namespace=\"\(context.namespace)\",pod=~\"hdfs-namenode-[0,1]\"}) [5m:1m]) > 0"
												"duration": "30s"
												"labels": {
													"severity": "critical"
													"channel":  "grafana_oncall"
												}
												"annotations": {
													"summary":     "Namenode not healthy (instance {{$labels.instance}})"
													"description": "Namenode pod has been in a non-ready state for longer than 5 minutes. VALUE={{$value}} LABELS={{$labels}}"
												}
											},
											{
												"alert":    "\(context.namespace)-\(context.name)-JournalnodePodNotReady"
												"expr":     "min_over_time(sum by(namespace, pod, phase) (kube_pod_status_phase{phase=~\"Pending|Unknown|Failed\",namespace=\"\(context.namespace)\",pod=~\"hdfs-journalnode-[0,1,2]\"}) [5m:1m]) > 0"
												"duration": "30s"
												"labels": {
													"severity": "critical"
													"channel":  "grafana_oncall"
												}
												"annotations": {
													"summary":     "Journalnode not healthy (instance {{$labels.instance}})"
													"description": "Journalnode pod has been in a non-ready state for longer than 5 minutes. VALUE={{$value}} LABELS={{$labels}}"
												}
											},
											{
												"alert":    "\(context.namespace)-\(context.name)-NamenodeContainerNotRunning"
												"expr":     "min_over_time(sum by (container) (kube_pod_container_status_running{namespace=\"\(context.namespace)\",pod=~\"hdfs-namenode-[0,1]\",container=\"hdfs-namenode\"}) [5m:1m]) < 2"
												"duration": "30s"
												"labels": {
													"severity": "warning"
													"channel":  "grafana_oncall"
												}
												"annotations": {
													"summary":     "Namenode not healthy (instance {{$labels.instance}})"
													"description": "Namenode container has been in a non-running state for longer than 5 minutes. VALUE={{$value}} LABELS={{$labels}}"
												}
											},
											{
												"alert":    "\(context.namespace)-\(context.name)-JournalnodeContainerNotRunning"
												"expr":     "min_over_time(sum by (container) (kube_pod_container_status_running{namespace=\"\(context.namespace)\",pod=~\"hdfs-journalnode-[0,1,2]\",container=\"hdfs-journalnode\"}) [5m:1m]) < 3"
												"duration": "30s"
												"labels": {
													"severity": "warning"
													"channel":  "grafana_oncall"
												}
												"annotations": {
													"summary":     "Journalnode not healthy (instance {{$labels.instance}})"
													"description": "Journalnode container has been in a non-running state for longer than 5 minutes. VALUE={{$value}} LABELS={{$labels}}"
												}
											},
											{
												"alert":    "\(context.namespace)-\(context.name)-NamenodeHeapUsedHigh"
												"expr":     "max(hadoop_namenode_memheapusedm{namespace=\"\(context.namespace)\"} / hadoop_namenode_memheapmaxm{namespace=\"\(context.namespace)\"}) > 0.8"
												"duration": "10s"
												"labels": {
													"severity": "warning"
													"channel":  "grafana_oncall"
												}
												"annotations": {
													"summary":     "Namenode heap used high (instance {{$labels.instance}})"
													"description": "Namenode has used more than 80% heap. VALUE={{$value}} LABELS={{$labels}}"
												}
											},
											{
												"alert":    "\(context.namespace)-\(context.name)-LackLiveDatanode"
												"expr":     "min_over_time(min(hadoop_namenode_numlivedatanodes{name=\"FSNamesystem\"}) [5m:1m]) < 3"
												"duration": "10s"
												"labels": {
													"severity": "critical"
													"channel":  "grafana_oncall"
												}
												"annotations": {
													"summary":     "Live datanode count is less than 3"
													"description": "Current live datanode count is {{$value}}. VALUE={{$value}} LABELS={{$labels}}"
												}
											},
											{
												"alert":    "\(context.namespace)-\(context.name)-FailedVolumes"
												"expr":     "max_over_time(sum(hadoop_datanode_numfailedvolumes{name=\"FSDatasetState\"}) [5m:1m]) > 0"
												"duration": "10s"
												"labels": {
													"severity": "critical"
													"channel":  "grafana_oncall"
												}
												"annotations": {
													"summary":     "Found failed volumes"
													"description": "Found failed volumes. VALUE={{$value}} LABELS={{$labels}}"
												}
											},
											{
												"alert":    "\(context.namespace)-\(context.name)-DeadDatanode"
												"expr":     "hadoop_namenode_numdeaddatanodes > 0"
												"duration": "5m"
												"labels": {
													"severity": "critical"
													"channel":  "grafana_oncall"
												}
												"annotations": {
													"summary":     "Found dead datanode"
													"description": "Found dead datanode. VALUE={{$value}} LABELS={{$labels}}"
												}
											},
											{
												"alert":    "\(context.namespace)-\(context.name)-MissingBlocks"
												"expr":     "hadoop_namenode_missingblocks > 0"
												"duration": "5m"
												"labels": {
													"severity": "critical"
													"channel":  "grafana_oncall"
												}
												"annotations": {
													"summary":     "Found missing blocks"
													"description": "Found missing blocks. VALUE={{$value}} LABELS={{$labels}}"
												}
											},
											{
												"alert":    "\(context.namespace)-\(context.name)-UnderReplicatedBlocks"
												"expr":     "hadoop_namenode_underreplicatedblocks > 0"
												"duration": "5m"
												"labels": {
													"severity": "warning"
													"channel":  "grafana_oncall"
												}
												"annotations": {
													"summary":     "Found under replicated blocks"
													"description": "Found under replicated blocks. VALUE={{$value}} LABELS={{$labels}}"
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
									"grafana_dashboard": "1"
								}
								"dashboard_data": {
									"hdfs-dashboard.json": "{\"annotations\":{\"list\":[{\"builtIn\":1,\"datasource\":{\"type\":\"datasource\",\"uid\":\"grafana\"},\"enable\":true,\"hide\":true,\"iconColor\":\"rgba(0, 211, 255, 1)\",\"name\":\"Annotations & Alerts\",\"target\":{\"limit\":100,\"matchAny\":false,\"tags\":[],\"type\":\"dashboard\"},\"type\":\"dashboard\"}]},\"description\":\"\",\"editable\":true,\"fiscalYearStartMonth\":0,\"graphTooltip\":1,\"id\":134,\"links\":[{\"asDropdown\":true,\"icon\":\"external link\",\"includeVars\":false,\"keepTime\":false,\"tags\":[\"BDOS OBS\"],\"targetBlank\":true,\"title\":\"快速入口\",\"tooltip\":\"\",\"type\":\"dashboards\",\"url\":\"\"}],\"liveNow\":false,\"panels\":[{\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":0},\"id\":87,\"title\":\"Overview\",\"type\":\"row\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Capacity statistics\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false}},\"mappings\":[],\"unit\":\"decbytes\"},\"overrides\":[]},\"gridPos\":{\"h\":7,\"w\":5,\"x\":0,\"y\":1},\"id\":83,\"links\":[],\"options\":{\"displayLabels\":[\"percent\",\"name\"],\"legend\":{\"displayMode\":\"list\",\"placement\":\"right\",\"values\":[\"value\"]},\"pieType\":\"donut\",\"reduceOptions\":{\"calcs\":[\"last\"],\"fields\":\"\",\"values\":false},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"max(hadoop_namenode_capacitytotal{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"})\",\"intervalFactor\":2,\"legendFormat\":\"total\",\"metric\":\"hadoop_namenode_capacitytotal\",\"range\":true,\"refId\":\"A\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"max(hadoop_namenode_capacityused{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"})\",\"intervalFactor\":2,\"legendFormat\":\"used\",\"metric\":\"hadoop_namenode_capacityused\",\"range\":true,\"refId\":\"B\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"max(hadoop_namenode_capacityusednondfs{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"})\",\"intervalFactor\":2,\"legendFormat\":\"non-dfs\",\"metric\":\"hadoop_namenode_capacityusednondfs\",\"range\":true,\"refId\":\"C\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"max(hadoop_namenode_capacityremaining{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"})\",\"intervalFactor\":2,\"legendFormat\":\"remaining\",\"metric\":\"hadoop_namenode_capacityremaining\",\"range\":true,\"refId\":\"D\",\"step\":4}],\"title\":\"容量统计\",\"type\":\"piechart\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Block statistics \",\"fieldConfig\":{\"defaults\":{\"mappings\":[{\"options\":{\"from\":1,\"result\":{\"color\":\"red\",\"index\":1},\"to\":10000000},\"type\":\"range\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":7,\"w\":5,\"x\":5,\"y\":1},\"id\":84,\"links\":[],\"options\":{\"colorMode\":\"background\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"auto\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"max(hadoop_namenode_underreplicatedblocks{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"})\",\"intervalFactor\":2,\"legendFormat\":\"under replicated\",\"metric\":\"hadoop_namenode_underreplicatedblocks\",\"range\":true,\"refId\":\"D\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"max(hadoop_namenode_corruptblocks{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"}) \",\"intervalFactor\":2,\"legendFormat\":\"corrupt\",\"metric\":\"hadoop_namenode_corruptblocks\",\"range\":true,\"refId\":\"E\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"max(hadoop_namenode_missingblocks{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"})\",\"intervalFactor\":2,\"legendFormat\":\"missing\",\"metric\":\"hadoop_namenode_missingblocks\",\"range\":true,\"refId\":\"J\",\"step\":4}],\"title\":\"区块统计 \",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Total number of failed volumes\",\"fieldConfig\":{\"defaults\":{\"mappings\":[{\"options\":{\"from\":1,\"result\":{\"color\":\"red\",\"index\":0},\"to\":99999},\"type\":\"range\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null}]},\"unit\":\"short\"},\"overrides\":[{\"matcher\":{\"id\":\"byName\",\"options\":\"Live DataNodes\"},\"properties\":[{\"id\":\"mappings\",\"value\":[{\"options\":{\"from\":0,\"result\":{\"color\":\"red\",\"index\":0},\"to\":2},\"type\":\"range\"}]}]}]},\"gridPos\":{\"h\":7,\"w\":6,\"x\":10,\"y\":1},\"id\":85,\"links\":[],\"options\":{\"colorMode\":\"background\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"auto\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"max(hadoop_namenode_numlivedatanodes{namespace=\\\"$namespace\\\"})\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"Live DataNodes\",\"metric\":\"hadoop_datanode_numfailedvolumes\",\"range\":true,\"refId\":\"B\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"max(hadoop_namenode_numdeaddatanodes{namespace=\\\"$namespace\\\"})\",\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"Dead DataNodes\",\"metric\":\"hadoop_datanode_numfailedvolumes\",\"range\":true,\"refId\":\"A\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"max(hadoop_namenode_numstaledatanodes{namespace=\\\"$namespace\\\"})\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"Stale DataNodes\",\"metric\":\"hadoop_datanode_numfailedvolumes\",\"range\":true,\"refId\":\"C\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"sum(hadoop_datanode_numfailedvolumes{namespace=\\\"$namespace\\\"})/2\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"Failed Volumes\",\"metric\":\"hadoop_datanode_numfailedvolumes\",\"range\":true,\"refId\":\"D\",\"step\":4}],\"title\":\"# DataNodes\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Total number of failed volumes\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[{\"options\":{\"from\":1,\"result\":{\"color\":\"red\",\"index\":0},\"to\":99999},\"type\":\"range\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null}]},\"unit\":\"short\"},\"overrides\":[{\"matcher\":{\"id\":\"byName\",\"options\":\"Live DataNodes\"},\"properties\":[{\"id\":\"mappings\",\"value\":[{\"options\":{\"from\":0,\"result\":{\"color\":\"red\",\"index\":0},\"to\":2},\"type\":\"range\"}]}]}]},\"gridPos\":{\"h\":7,\"w\":8,\"x\":16,\"y\":1},\"id\":88,\"links\":[],\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"max(hadoop_namenode_numdeaddatanodes{namespace=\\\"$namespace\\\"})\",\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"Dead DataNodes\",\"metric\":\"hadoop_datanode_numfailedvolumes\",\"range\":true,\"refId\":\"A\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"max(hadoop_namenode_numlivedatanodes{namespace=\\\"$namespace\\\"})\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"Live DataNodes\",\"metric\":\"hadoop_datanode_numfailedvolumes\",\"range\":true,\"refId\":\"B\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"max(hadoop_namenode_numstaledatanodes{namespace=\\\"$namespace\\\"})\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"Stale DataNodes\",\"metric\":\"hadoop_datanode_numfailedvolumes\",\"range\":true,\"refId\":\"C\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"sum(hadoop_datanode_numfailedvolumes{namespace=\\\"$namespace\\\"})/2\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"Failed Volumes\",\"metric\":\"hadoop_datanode_numfailedvolumes\",\"range\":true,\"refId\":\"D\",\"step\":4}],\"title\":\"# DataNodes\",\"type\":\"timeseries\"},{\"collapsed\":true,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":8},\"id\":72,\"panels\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Capacity statistics\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"decbytes\"},\"overrides\":[]},\"gridPos\":{\"h\":7,\"w\":12,\"x\":0,\"y\":9},\"id\":54,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"expr\":\"max(hadoop_namenode_capacitytotal{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"})\",\"intervalFactor\":2,\"legendFormat\":\"capacity total\",\"metric\":\"hadoop_namenode_capacitytotal\",\"refId\":\"A\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"expr\":\"max(hadoop_namenode_capacityused{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"})\",\"intervalFactor\":2,\"legendFormat\":\"capacity used\",\"metric\":\"hadoop_namenode_capacityused\",\"refId\":\"B\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"expr\":\"max(hadoop_namenode_capacityusednondfs{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"})\",\"intervalFactor\":2,\"legendFormat\":\"capacity non-dfs\",\"metric\":\"hadoop_namenode_capacityusednondfs\",\"refId\":\"C\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"expr\":\"max(hadoop_namenode_capacityremaining{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"})\",\"intervalFactor\":2,\"legendFormat\":\"capacity remaining\",\"metric\":\"hadoop_namenode_capacityremaining\",\"refId\":\"D\",\"step\":4}],\"title\":\"容量统计\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Block statistics \",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":7,\"w\":12,\"x\":12,\"y\":9},\"id\":55,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"max(hadoop_namenode_blockcapacity{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"})\",\"hide\":false,\"intervalFactor\":2,\"legendFormat\":\"capacity\",\"metric\":\"hadoop_namenode_blockcapacity\",\"range\":true,\"refId\":\"A\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"max(hadoop_namenode_blockstotal{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"}) \",\"intervalFactor\":2,\"legendFormat\":\"allocated\",\"metric\":\"hadoop_namenode_blockstotal\",\"range\":true,\"refId\":\"B\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"max(hadoop_namenode_pendingreplicationblocks{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"}) \",\"intervalFactor\":2,\"legendFormat\":\"pending replication\",\"metric\":\"hadoop_namenode_pendingreplicationblocks\",\"range\":true,\"refId\":\"C\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"max(hadoop_namenode_underreplicatedblocks{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"})\",\"intervalFactor\":2,\"legendFormat\":\"under replicated\",\"metric\":\"hadoop_namenode_underreplicatedblocks\",\"range\":true,\"refId\":\"D\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"max(hadoop_namenode_corruptblocks{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"}) \",\"intervalFactor\":2,\"legendFormat\":\"corrupt\",\"metric\":\"hadoop_namenode_corruptblocks\",\"range\":true,\"refId\":\"E\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"max(hadoop_namenode_scheduledreplicationblocks{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"}) \",\"intervalFactor\":2,\"legendFormat\":\"scheduled replications\",\"metric\":\"hadoop_namenode_scheduledreplicationblocks\",\"range\":true,\"refId\":\"F\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"max(hadoop_namenode_pendingdeletionblocks{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"})\",\"intervalFactor\":2,\"legendFormat\":\"pending deletion\",\"metric\":\"hadoop_namenode_pendingdeletionblocks\",\"range\":true,\"refId\":\"G\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"max(hadoop_namenode_excessblocks{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"})\",\"intervalFactor\":2,\"legendFormat\":\"excess\",\"metric\":\"hadoop_namenode_excessblocks\",\"range\":true,\"refId\":\"H\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"max(hadoop_namenode_missingblocks{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"})\",\"intervalFactor\":2,\"legendFormat\":\"missing\",\"metric\":\"hadoop_namenode_missingblocks\",\"range\":true,\"refId\":\"J\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"expr\":\"max(hadoop_namenode_postponedmisreplicatedblocks{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"})\",\"intervalFactor\":2,\"legendFormat\":\"HA-blocks postponed to replicate\",\"metric\":\"hadoop_namenode_postponedmisreplicatedblocks\",\"refId\":\"I\",\"step\":4}],\"title\":\"区块统计 \",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Current number of files and directories (same as FilesTotal)\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":7,\"w\":12,\"x\":0,\"y\":16},\"id\":39,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"max(hadoop_namenode_filestotal{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"})\",\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"metric\":\"hadoop_namenode_totalfiles\",\"range\":true,\"refId\":\"A\",\"step\":4}],\"title\":\"文件数量\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Current number of allocated blocks in the system\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":7,\"w\":12,\"x\":12,\"y\":16},\"id\":40,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"last\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"max(hadoop_namenode_blockstotal{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"})\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"metric\":\"hadoop_namenode_blockstotal\",\"range\":true,\"refId\":\"A\",\"step\":4}],\"title\":\"已分配区块数 \",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"The interval between FSNameSystem starts and the last time safemode leaves in milliseconds.  (sometimes not equal to the time in SafeMode, see HDFS-5156)\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"ms\"},\"overrides\":[]},\"gridPos\":{\"h\":7,\"w\":12,\"x\":0,\"y\":23},\"id\":37,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_namenode_safemodetime{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"}\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"metric\":\"hadoop_namenode_safemodetime\",\"range\":true,\"refId\":\"A\",\"step\":4}],\"title\":\"安全模式时间\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"current number of connections\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":7,\"w\":12,\"x\":12,\"y\":23},\"id\":56,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"expr\":\"max(hadoop_namenode_totalload{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"})\",\"intervalFactor\":2,\"legendFormat\":\"{{instance}}\",\"metric\":\"hadoop_namenode_totalload\",\"refId\":\"A\",\"step\":4}],\"title\":\"连接数目\",\"type\":\"timeseries\"}],\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"refId\":\"A\"}],\"title\":\"NameNode - DFS\",\"type\":\"row\"},{\"collapsed\":true,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":9},\"id\":73,\"panels\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Total number of bytes read from DataNode\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"binBps\"},\"overrides\":[]},\"gridPos\":{\"h\":10,\"w\":6,\"x\":0,\"y\":10},\"id\":3,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"rate(hadoop_datanode_bytesread{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}[$__rate_interval])\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"metric\":\"hadoop_datanode_bytesread\",\"range\":true,\"refId\":\"A\",\"step\":10}],\"title\":\"读取字节量\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Total number of bytes written to DataNode\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"binBps\"},\"overrides\":[]},\"gridPos\":{\"h\":10,\"w\":6,\"x\":6,\"y\":10},\"id\":4,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"rate(hadoop_datanode_byteswritten{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}[$__rate_interval])\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"metric\":\"hadoop_datanode_byteswritten\",\"range\":true,\"refId\":\"A\",\"step\":10}],\"title\":\"写入字节量\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Total number of blocks read from DataNode\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"decimals\":2,\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"cps\"},\"overrides\":[]},\"gridPos\":{\"h\":10,\"w\":6,\"x\":12,\"y\":10},\"id\":5,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"rate(hadoop_datanode_blocksread{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}[$__rate_interval])\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"metric\":\"hadoop_datanode_blocksread\",\"range\":true,\"refId\":\"A\",\"step\":10}],\"title\":\"读取区块量\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Total number of blocks written to DataNode\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"decimals\":2,\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"cps\"},\"overrides\":[]},\"gridPos\":{\"h\":10,\"w\":6,\"x\":18,\"y\":10},\"id\":6,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"rate(hadoop_datanode_blockswritten{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}[$__rate_interval])\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"metric\":\"hadoop_datanode_blockswritten\",\"range\":true,\"refId\":\"A\",\"step\":10}],\"title\":\"写入区块量\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Total number of read operations\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"decimals\":2,\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"rps\"},\"overrides\":[]},\"gridPos\":{\"h\":10,\"w\":6,\"x\":0,\"y\":20},\"id\":10,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"rate(hadoop_datanode_readblockopnumops{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}[$__rate_interval])\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"metric\":\"hadoop_datanode_readblockopnumops\",\"range\":true,\"refId\":\"A\",\"step\":10}],\"title\":\"读取操作数量（平均每秒）\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Average time of read operations in milliseconds\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"ms\"},\"overrides\":[]},\"gridPos\":{\"h\":10,\"w\":6,\"x\":6,\"y\":20},\"id\":11,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_datanode_readblockopavgtime{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"metric\":\"hadoop_datanode_readblockopavgtime\",\"range\":true,\"refId\":\"A\",\"step\":10}],\"title\":\"平均读取操作时间\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Total number of write operations\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"wps\"},\"overrides\":[]},\"gridPos\":{\"h\":10,\"w\":6,\"x\":12,\"y\":20},\"id\":12,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"rate(hadoop_datanode_writeblockopnumops{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}[$__rate_interval])\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"metric\":\"hadoop_datanode_writeblockopnumops\",\"range\":true,\"refId\":\"A\",\"step\":10}],\"title\":\"写入操作数量（平均每秒）\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Average time of write operations in milliseconds\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"ms\"},\"overrides\":[]},\"gridPos\":{\"h\":10,\"w\":6,\"x\":18,\"y\":20},\"id\":13,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_datanode_writeblockopavgtime{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"metric\":\"hadoop_datanode_writeblockopavgtime\",\"range\":true,\"refId\":\"A\",\"step\":10}],\"title\":\"平均写入操作时间\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Total number of flushes\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"decimals\":2,\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"cps\"},\"overrides\":[]},\"gridPos\":{\"h\":10,\"w\":12,\"x\":0,\"y\":30},\"id\":14,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"rate(hadoop_datanode_flushnanosnumops{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}[$__rate_interval])\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"metric\":\"hadoop_datanode_flushnanosnumops\",\"range\":true,\"refId\":\"A\",\"step\":4}],\"title\":\"Flush rate\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Average flush time in nanoseconds\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"ns\"},\"overrides\":[]},\"gridPos\":{\"h\":10,\"w\":12,\"x\":12,\"y\":30},\"id\":15,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_datanode_flushnanosavgtime{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"metric\":\"hadoop_datanode_flushnanosavgtime\",\"range\":true,\"refId\":\"A\",\"step\":4}],\"title\":\"平均flush时间\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Total number of fsync\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":10,\"w\":12,\"x\":0,\"y\":40},\"id\":7,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_datanode_fsynccount{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"metric\":\"hadoop_datanode_fsynccount\",\"range\":true,\"refId\":\"A\",\"step\":4}],\"title\":\"文件同步数量\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Total number of sending packets\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"pps\"},\"overrides\":[]},\"gridPos\":{\"h\":10,\"w\":12,\"x\":12,\"y\":40},\"id\":18,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"rate(hadoop_datanode_senddatapackettransfernanosnumops{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}[$__rate_interval])\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"metric\":\"hadoop_datanode_senddatapackettransfernanosnumops\",\"range\":true,\"refId\":\"A\",\"step\":4}],\"title\":\"发送包数目\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Average transfer time of sending packets in nanoseconds\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"ns\"},\"overrides\":[]},\"gridPos\":{\"h\":10,\"w\":12,\"x\":0,\"y\":50},\"id\":19,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_datanode_senddatapackettransfernanosavgtime{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"metric\":\"hadoop_datanode_senddatapackettransfernanosavgtime\",\"range\":true,\"refId\":\"A\",\"step\":4}],\"title\":\"发送包平均传输时间\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Average waiting time of sending packets in nanoseconds\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"ns\"},\"overrides\":[]},\"gridPos\":{\"h\":10,\"w\":12,\"x\":12,\"y\":50},\"id\":17,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_datanode_senddatapacketblockedonnetworknanosavgtime\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"metric\":\"hadoop_datanode_senddatapacketblockedonnetworknanosavgtime\",\"range\":true,\"refId\":\"A\",\"step\":4}],\"title\":\"发送包平均等待时间\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Total number of volume failures occurred\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":10,\"w\":12,\"x\":0,\"y\":60},\"id\":8,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_datanode_volumefailures{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"metric\":\"hadoop_datanode_volumefailures\",\"range\":true,\"refId\":\"A\",\"step\":4}],\"title\":\"卷故障次数\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Total number of failed volumes\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":10,\"w\":12,\"x\":12,\"y\":60},\"id\":9,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\",\"sortBy\":\"Last *\",\"sortDesc\":false},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_datanode_numfailedvolumes{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}\",\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}} {{name}}\",\"metric\":\"hadoop_datanode_numfailedvolumes\",\"range\":true,\"refId\":\"A\",\"step\":4}],\"title\":\"卷故障数目\",\"type\":\"timeseries\"}],\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"refId\":\"A\"}],\"title\":\"DataNode - DFS\",\"type\":\"row\"},{\"collapsed\":true,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":10},\"id\":74,\"panels\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"decimals\":2,\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"cps\"},\"overrides\":[]},\"gridPos\":{\"h\":10,\"w\":24,\"x\":0,\"y\":11},\"id\":63,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"rate(hadoop_namenode_gccount{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"}[$__rate_interval])\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"metric\":\"hadoop_namenode_gccount\",\"range\":true,\"refId\":\"A\",\"step\":4}],\"title\":\"GC Rate\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Current heap memory used/commited/max in MB\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"decmbytes\"},\"overrides\":[]},\"gridPos\":{\"h\":12,\"w\":24,\"x\":0,\"y\":21},\"id\":78,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_namenode_memheapusedm{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"}\",\"intervalFactor\":2,\"legendFormat\":\"use: {{pod}}\",\"metric\":\"hadoop_namenode_memheapusedm\",\"range\":true,\"refId\":\"A\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_namenode_memheapcommittedm{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"}\",\"hide\":false,\"intervalFactor\":2,\"legendFormat\":\"commit: {{pod}}\",\"metric\":\"hadoop_namenode_memheapusedm\",\"range\":true,\"refId\":\"B\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_namenode_memheapmaxm{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"}\",\"hide\":false,\"intervalFactor\":2,\"legendFormat\":\"max: {{pod}}\",\"metric\":\"hadoop_namenode_memheapusedm\",\"range\":true,\"refId\":\"C\",\"step\":4}],\"title\":\"堆内存\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Current non-heap memory used/commited/max in MB\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"decmbytes\"},\"overrides\":[]},\"gridPos\":{\"h\":12,\"w\":24,\"x\":0,\"y\":33},\"id\":79,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\",\"sortBy\":\"Last *\",\"sortDesc\":false},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_namenode_memnonheapusedm{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"}\",\"intervalFactor\":2,\"legendFormat\":\"use: {{pod}}\",\"metric\":\"hadoop_namenode_memheapusedm\",\"range\":true,\"refId\":\"A\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_namenode_memnonheapcommittedm{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"}\",\"hide\":false,\"intervalFactor\":2,\"legendFormat\":\"commit: {{pod}}\",\"metric\":\"hadoop_namenode_memheapusedm\",\"range\":true,\"refId\":\"B\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_namenode_memnonheapmaxm{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"}\",\"hide\":false,\"intervalFactor\":2,\"legendFormat\":\"max: {{pod}}\",\"metric\":\"hadoop_namenode_memheapusedm\",\"range\":true,\"refId\":\"C\",\"step\":4}],\"title\":\"非堆内存\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":11,\"w\":24,\"x\":0,\"y\":45},\"id\":80,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\",\"sortBy\":\"Last *\",\"sortDesc\":true},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_namenode_threadsrunnable{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"}\",\"intervalFactor\":2,\"legendFormat\":\"RUNNABLE: {{pod}}\",\"metric\":\"hadoop_namenode_threadsrunnable\",\"range\":true,\"refId\":\"A\",\"step\":10},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_namenode_threadswaiting{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"}\",\"hide\":false,\"intervalFactor\":2,\"legendFormat\":\"WAITING: {{pod}}\",\"metric\":\"hadoop_namenode_threadsrunnable\",\"range\":true,\"refId\":\"B\",\"step\":10},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_namenode_threadstimedwaiting{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"}\",\"hide\":false,\"intervalFactor\":2,\"legendFormat\":\"TIMED_WAITING: {{pod}}\",\"metric\":\"hadoop_namenode_threadsrunnable\",\"range\":true,\"refId\":\"C\",\"step\":10},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_namenode_threadsblocked{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"}\",\"hide\":false,\"intervalFactor\":2,\"legendFormat\":\"BLOCKED: {{pod}}\",\"metric\":\"hadoop_namenode_threadsrunnable\",\"range\":true,\"refId\":\"D\",\"step\":10}],\"title\":\"线程数\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":14,\"w\":24,\"x\":0,\"y\":56},\"id\":68,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\",\"max\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"increase(hadoop_namenode_loginfo{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"}[1m])\",\"intervalFactor\":2,\"legendFormat\":\"INFO: {{pod}}\",\"metric\":\"hadoop_namenode_loginfo\",\"range\":true,\"refId\":\"A\",\"step\":10},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"increase(hadoop_namenode_logwarn{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"}[1m])\",\"hide\":false,\"intervalFactor\":2,\"legendFormat\":\"WARN: {{pod}}\",\"metric\":\"hadoop_namenode_loginfo\",\"range\":true,\"refId\":\"B\",\"step\":10},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"increase(hadoop_namenode_logerror{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"}[1m])\",\"hide\":false,\"intervalFactor\":2,\"legendFormat\":\"ERROR: {{pod}}\",\"metric\":\"hadoop_namenode_loginfo\",\"range\":true,\"refId\":\"C\",\"step\":10},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"increase(hadoop_namenode_logfatal{namespace=\\\"$namespace\\\",pod=~\\\"$namenode\\\"}[1m])\",\"hide\":false,\"intervalFactor\":2,\"legendFormat\":\"FATAL: {{pod}}\",\"metric\":\"hadoop_namenode_loginfo\",\"range\":true,\"refId\":\"D\",\"step\":10}],\"title\":\"日志数(每分钟)\",\"type\":\"timeseries\"}],\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"refId\":\"A\"}],\"title\":\"NameNode - JVM\",\"type\":\"row\"},{\"collapsed\":true,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":11},\"id\":75,\"panels\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Total GC count\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"decimals\":2,\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"cps\"},\"overrides\":[]},\"gridPos\":{\"h\":9,\"w\":24,\"x\":0,\"y\":12},\"id\":77,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"rate(hadoop_datanode_gccount[$__rate_interval])\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"metric\":\"hadoop_namenode_gccount\",\"range\":true,\"refId\":\"A\",\"step\":4}],\"title\":\"GC Rate\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Current heap memory used/commited/max in MB\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"decmbytes\"},\"overrides\":[]},\"gridPos\":{\"h\":12,\"w\":24,\"x\":0,\"y\":21},\"id\":41,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_datanode_memheapusedm{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}\",\"intervalFactor\":2,\"legendFormat\":\"use: {{pod}}\",\"metric\":\"hadoop_namenode_memheapusedm\",\"range\":true,\"refId\":\"A\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_datanode_memheapcommittedm{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}\",\"hide\":false,\"intervalFactor\":2,\"legendFormat\":\"commit: {{pod}}\",\"metric\":\"hadoop_namenode_memheapusedm\",\"range\":true,\"refId\":\"B\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_datanode_memheapmaxm{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}\",\"hide\":false,\"intervalFactor\":2,\"legendFormat\":\"max: {{pod}}\",\"metric\":\"hadoop_namenode_memheapusedm\",\"range\":true,\"refId\":\"C\",\"step\":4}],\"title\":\"堆内存\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Current non-heap memory used/commited/max in MB\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"decmbytes\"},\"overrides\":[]},\"gridPos\":{\"h\":12,\"w\":24,\"x\":0,\"y\":33},\"id\":76,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\",\"sortBy\":\"Last *\",\"sortDesc\":false},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_datanode_memnonheapusedm{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}\",\"intervalFactor\":2,\"legendFormat\":\"use: {{pod}}\",\"metric\":\"hadoop_namenode_memheapusedm\",\"range\":true,\"refId\":\"A\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_datanode_memnonheapcommittedm{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}\",\"hide\":false,\"intervalFactor\":2,\"legendFormat\":\"commit: {{pod}}\",\"metric\":\"hadoop_namenode_memheapusedm\",\"range\":true,\"refId\":\"B\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_datanode_memnonheapmaxm{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}\",\"hide\":false,\"intervalFactor\":2,\"legendFormat\":\"max: {{pod}}\",\"metric\":\"hadoop_namenode_memheapusedm\",\"range\":true,\"refId\":\"C\",\"step\":4}],\"title\":\"非堆内存\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Current number of RUNNABLE threads\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":12,\"w\":24,\"x\":0,\"y\":45},\"id\":64,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_datanode_threadsrunnable{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}\",\"intervalFactor\":2,\"legendFormat\":\"RUNNABLE: {{pod}}\",\"metric\":\"hadoop_namenode_threadsrunnable\",\"range\":true,\"refId\":\"A\",\"step\":10},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_datanode_threadswaiting{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}\",\"hide\":false,\"intervalFactor\":2,\"legendFormat\":\"WAITING: {{pod}}\",\"metric\":\"hadoop_namenode_threadsrunnable\",\"range\":true,\"refId\":\"B\",\"step\":10},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_datanode_threadstimedwaiting{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}\",\"hide\":false,\"intervalFactor\":2,\"legendFormat\":\"TIMED_WAITING: {{pod}}\",\"metric\":\"hadoop_namenode_threadsrunnable\",\"range\":true,\"refId\":\"C\",\"step\":10},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"hadoop_datanode_threadsblocked{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}\",\"hide\":false,\"intervalFactor\":2,\"legendFormat\":\"BLOCKED: {{pod}}\",\"metric\":\"hadoop_namenode_threadsrunnable\",\"range\":true,\"refId\":\"D\",\"step\":10}],\"title\":\"线程数\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":14,\"w\":24,\"x\":0,\"y\":57},\"id\":82,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\",\"max\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"increase(hadoop_datanode_loginfo{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}[1m])\",\"intervalFactor\":2,\"legendFormat\":\"INFO: {{pod}}\",\"metric\":\"hadoop_namenode_loginfo\",\"range\":true,\"refId\":\"A\",\"step\":10},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"increase(hadoop_datanode_logwarn{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}[1m])\",\"hide\":false,\"intervalFactor\":2,\"legendFormat\":\"WARN: {{pod}}\",\"metric\":\"hadoop_namenode_loginfo\",\"range\":true,\"refId\":\"B\",\"step\":10},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"increase(hadoop_datanode_logerror{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}[1m])\",\"hide\":false,\"intervalFactor\":2,\"legendFormat\":\"ERROR: {{pod}}\",\"metric\":\"hadoop_namenode_loginfo\",\"range\":true,\"refId\":\"C\",\"step\":10},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"increase(hadoop_datanode_logfatal{namespace=\\\"$namespace\\\",pod=~\\\"$datanode\\\"}[1m])\",\"hide\":false,\"intervalFactor\":2,\"legendFormat\":\"FATAL: {{pod}}\",\"metric\":\"hadoop_namenode_loginfo\",\"range\":true,\"refId\":\"D\",\"step\":10}],\"title\":\"日志数(每分钟)\",\"type\":\"timeseries\"}],\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"refId\":\"A\"}],\"title\":\"DataNode - JVM\",\"type\":\"row\"}],\"refresh\":\"1m\",\"schemaVersion\":36,\"style\":\"dark\",\"tags\":[],\"templating\":{\"list\":[{\"current\":{\"selected\":false,\"text\":\"Prometheus\",\"value\":\"Prometheus\"},\"hide\":0,\"includeAll\":false,\"label\":\"prometheus\",\"multi\":false,\"name\":\"DS_PROMETHEUS\",\"options\":[],\"query\":\"prometheus\",\"refresh\":1,\"regex\":\"\",\"skipUrlSync\":false,\"type\":\"datasource\"},{\"current\":{\"selected\":false,\"text\":\"admin\",\"value\":\"admin\"},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"definition\":\"label_values(hadoop_namenode_free, namespace)\",\"hide\":0,\"includeAll\":false,\"multi\":false,\"name\":\"namespace\",\"options\":[],\"query\":{\"query\":\"label_values(hadoop_namenode_free, namespace)\",\"refId\":\"StandardVariableQuery\"},\"refresh\":1,\"regex\":\"\",\"skipUrlSync\":false,\"sort\":0,\"type\":\"query\"},{\"current\":{\"selected\":true,\"text\":[\"All\"],\"value\":[\"$__all\"]},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"definition\":\"label_values(hadoop_namenode_free{namespace=\\\"$namespace\\\"}, pod)\",\"hide\":0,\"includeAll\":true,\"label\":\"namenode\",\"multi\":true,\"name\":\"namenode\",\"options\":[],\"query\":{\"query\":\"label_values(hadoop_namenode_free{namespace=\\\"$namespace\\\"}, pod)\",\"refId\":\"StandardVariableQuery\"},\"refresh\":1,\"regex\":\"\",\"skipUrlSync\":false,\"sort\":0,\"tagValuesQuery\":\"\",\"tagsQuery\":\"\",\"type\":\"query\",\"useTags\":false},{\"allValue\":\"\",\"current\":{\"selected\":true,\"text\":[\"All\"],\"value\":[\"$__all\"]},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"definition\":\"label_values(hadoop_datanode_capacity{namespace=\\\"$namespace\\\"}, pod)\",\"hide\":0,\"includeAll\":true,\"label\":\"datanode\",\"multi\":true,\"name\":\"datanode\",\"options\":[],\"query\":{\"query\":\"label_values(hadoop_datanode_capacity{namespace=\\\"$namespace\\\"}, pod)\",\"refId\":\"StandardVariableQuery\"},\"refresh\":1,\"regex\":\"\",\"skipUrlSync\":false,\"sort\":0,\"tagValuesQuery\":\"\",\"tagsQuery\":\"\",\"type\":\"query\",\"useTags\":false}]},\"time\":{\"from\":\"now-5m\",\"to\":\"now\"},\"timepicker\":{\"refresh_intervals\":[\"5s\",\"10s\",\"30s\",\"1m\",\"5m\",\"15m\",\"30m\",\"1h\",\"2h\",\"1d\"],\"time_options\":[\"5m\",\"15m\",\"1h\",\"6h\",\"12h\",\"24h\",\"2d\",\"7d\",\"30d\"]},\"timezone\":\"browser\",\"title\":\"HDFS监控面板\",\"uid\":\"hdfs\",\"version\":53,\"weekStart\":\"\"}"
								}
							}
						},
					]
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
				{
					"name": "apply-once"
					"type": "apply-once"
					"properties": {
						"enable": true
						"rules": [
							{
								"strategy": {
									"path": [
										"*",
									]
								}
								"selector": {
									"resourceTypes": [
										"Job",
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
		// +ui:title=组件依赖
		// +ui:order=1
		dependencies: {
			// +ui:description=Zookeeper 地址
			// +ui:order=1
			// +err:options={"required":"请先安装 Zookeeper"}
			zookeeperQuorum: string
			// +ui:description=Zookeeper Namenode 高可用状态所在的 Zookeeper 节点
			// +ui:order=2
			// +ui:options={"disabled":true}
			zookeeperParentZnode: *"/hadoop-ha/hdfs-k8s" | string
		}
		// +ui:title=Namenode
		// +ui:order=2
		namenode: {
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
					memory: *"1024Mi" | string
				}
			}
			// +ui:description=最大的堆内存百分比
			// +ui:order=2
			// +pattern=^[1-9]\d?\.\d+$
			// +err:options={"pattern":"请输入正确的浮点数，如60.0"}
			maxRAMPercentage: *"60.0" | string
			// +ui:description=存储
			// +ui:order=3
			persistence: {
				// +ui:description=持久卷大小
				// +pattern=^([1-9]\d*)(Ti|Gi|Mi)$
				// +err:options={"pattern":"请输入正确的存储格式，如10Gi"}
				size: *"10Gi" | string
			}
			// +ui:description=Namenode 高可用
			// +ui:order=4
			// +ui:options={"disabled":true}
			HAEnabled: *true | bool
		}
		// +ui:title=Journalnode
		// +ui:order=3
		journalnode: {
			// +ui:description=Journal Node 数量
			// +ui:order=1
			// +minimum=3
			quorumSize: *3 | int
			// +ui:description=资源规格
			// +ui:order=2
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
			// +ui:description=存储
			// +ui:order=3
			persistence: {
				// +ui:description=持久卷大小
				// +pattern=^([1-9]\d*)(Ti|Gi|Mi)$
				// +err:options={"pattern":"请输入正确的存储格式，如10Gi"}
				size: *"10Gi" | string
			}
		}
		// +ui:title=Datanode
		// +ui:order=4
		datanode: {
			// +ui:description=副本数
			// +ui:order=1
			// +minimum=1
			replicas: *3 | int
			// +ui:description=资源规格
			// +ui:order=2
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
					memory: *"1024Mi" | string
				}
			}
			// +ui:description=最大的堆内存百分比
			// +ui:order=3
			// +pattern=^[1-9]\d?\.\d+$
			// +err:options={"pattern":"请输入正确的浮点数，如60.0"}
			maxRAMPercentage: *"60.0" | string
			// +ui:description=存储
			// +ui:order=4
			persistence: {
				// +ui:description=持久卷大小
				// +pattern=^([1-9]\d*)(Ti|Gi|Mi)$
				// +err:options={"pattern":"请输入正确的存储格式，如10Gi"}
				size: *"10Gi" | string
			}
		}
		// +ui:description=自定义 core-site.xml 内容
		// +ui:order=10
		coreSite: {...}
		// +ui:description=自定义 hdfs-site.xml 内容
		// +ui:order=11
		hdfsSite: {...}
		// +ui:description=Helm Chart 版本号
		// +ui:order=100
		// +ui:options={"disabled":true}
		chartVersion: string
		// +ui:description=Hadoop 镜像版本
		// +ui:order=101
		// +ui:options={"disabled":true}
		imageTag: *"v1.0.0-3.1.1" | string
		// +ui:description=采集日志到 Loki
		// +ui:order=7
		// +ui:hidden=true
		logsPromtailEnabled: *true | bool
	}
}
