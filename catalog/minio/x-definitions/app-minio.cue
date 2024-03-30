"minio": {
	annotations: {}
	labels: {}
	attributes: {
		apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "Application"
				type:       "minio"
			}
		}
	}
	description: "minio"
	type:        "xdefinition"
}

template: {
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
						chart:           "minio"
						releaseName:     context["name"]
						repoType:        "oci"
						targetNamespace: context["namespace"]
						url:             context["helm_repo_url"]
						values: {
							if parameter.affinity != _|_ {
								affinity: parameter.affinity
							}
							auth: {
								rootPassword: parameter.auth.rootPassword
								rootUser:     parameter.auth.rootUser
							}
							commonLabels: {
								release: "prometheus"
							}
							global: {
								imagePullSecrets: [
									context["K8S_IMAGE_PULL_SECRETS_NAME"],
								]
								imageRegistry: context["docker_registry"]
								storageClass:  context["storage_config.storage_class_mapping.local_disk"]
							}
							image: {
								debug: true
							}
							metrics: {
								enabled: true
								serviceMonitor: {
									enabled: false
								}
							}
							mode: parameter.mode
							persistence: {
								enabled: parameter.persistence.enabled
								size:    parameter.persistence.size
							}
							podAnnotations: {
								"prometheus.io/path":   "/minio/v2/metrics/cluster"
								"prometheus.io/port":   "9000"
								"prometheus.io/scrape": "true"
							}
							podLabels: {
								app: context["name"]
							}
							provisioning: {
								buckets: [
									{
										name: "default"
									},
									{
										name: "kdp-flink-checkpoint"
									},
								]
								enabled: true
							}
							resources: {
								limits: {
									cpu:    parameter.resources.limits.cpu
									memory: parameter.resources.limits.memory
								}
								requests: {
									cpu:    parameter.resources.requests.cpu
									memory: parameter.resources.requests.memory
								}
							}
							statefulset: {
								replicaCount: parameter.statefulset.replicaCount
								zones:        parameter.statefulset.zones
							}
						}
						version: "11.10.2"
					}
					traits: [
						{
							properties: {
								rules: [
									{
										host: context["name"] + "-" + context["namespace"] + "-api." + context["ingress.root_domain"]
										paths: [
											{
												path:        "/"
												serviceName: "minio"
												servicePort: 9000
											},
										]
									},
									{
										host: context["name"] + "-" + context["namespace"] + "-console." + context["ingress.root_domain"]
										paths: [
											{
												path:        "/"
												serviceName: "minio"
												servicePort: 9001
											},
										]
									},
								]
								tls: [
									{
										hosts: [
											context["name"] + "-" + context["namespace"] + "-api." + context["ingress.root_domain"],
											context["name"] + "-" + context["namespace"] + "-console." + context["ingress.root_domain"],
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
										path:     "/minio/v2/metrics/cluster"
										port:     9000
										portName: "minio-api"
									},
								]
								matchLabels: {
									"app.kubernetes.io/instance": "minio"
									"app.kubernetes.io/name":     "minio"
								}
								monitortype: "service"
								namespace:   context["namespace"]
							}
							type: "bdos-monitor"
						},
						{
							properties: {
								groups: [
									{
										name: "minio.rules"
										rules: [
											{
												alert: "MinioDiskOffline"
												annotations: {
													description: "Minio disk has been offline for 5 minutes. Namespace: {{ $labels.namespace }}, pod: {{ $labels.pod }}"
													summary:     "Minio disk offline"
												}
												duration: "5m"
												expr:     "minio_cluster_disk_offline_total \u003e 0"
												labels: {
													severity: "warning"
												}
											},
											{
												alert: "MinioNodeOffline"
												annotations: {
													description: "Minio node has been offline for 5 minutes. Namespace: {{ $labels.namespace }}, pod: {{ $labels.pod }}"
													summary:     "Minio node offline"
												}
												duration: "5m"
												expr:     "minio_cluster_nodes_offline_total \u003e 0"
												labels: {
													severity: "warning"
												}
											},
											{
												alert: "MinioS3RequestError"
												annotations: {
													description: "Minio s3 request error. Namespace: {{ $labels.namespace }}, pod: {{ $labels.pod }}"
													summary:     "Minio s3 request error"
												}
												duration: "5m"
												expr:     "rate(minio_s3_requests_errors_total{}[5m]) \u003e 0"
												labels: {
													severity: "warning"
												}
											},
										]
									},
								]
								namespace: context["namespace"]
							}
							type: "bdos-prometheus-rules"
						},
					]
					type: "helm"
				},
				{
					name: context["name"] + "-context"
					properties: {
						apiVersion: "bdc.kdp.io/v1alpha1"
						kind:       "ContextSetting"
						metadata: {
							annotations: {
								"setting.ctx.bdc.kdp.io/origin": "system"
								"setting.ctx.bdc.kdp.io/type":   "minio"
							}
							name:      context["namespace"] + "-" + context["name"] + "-context"
							namespace: context["namespace"]
						}
						spec: {
							name: context["name"] + "-context"
							properties: {
								authSecretName: "minio"
								host:           context["name"] + "." + context["namespace"] + ".svc.cluster.local:9000"
							}
							type: "minio"
						}
					}
					type: "raw"
				},
				{
					name: "minio-grafana-dashboard"
					properties: {
						apiVersion: "v1"
						data: {
							"minio-dashboard.json": "{\"annotations\":{\"list\":[{\"builtIn\":1,\"datasource\":{\"type\":\"datasource\",\"uid\":\"grafana\"},\"enable\":true,\"hide\":true,\"iconColor\":\"rgba(0, 211, 255, 1)\",\"name\":\"Annotations \u0026 Alerts\",\"target\":{\"limit\":100,\"matchAny\":false,\"tags\":[],\"type\":\"dashboard\"},\"type\":\"dashboard\"}]},\"description\":\"MinIO Grafana Dashboard - https://min.io/\",\"editable\":true,\"fiscalYearStartMonth\":0,\"gnetId\":13502,\"graphTooltip\":0,\"id\":75,\"links\":[{\"icon\":\"external link\",\"includeVars\":true,\"keepTime\":true,\"tags\":[\"minio\"],\"type\":\"dashboards\"}],\"liveNow\":false,\"panels\":[{\"collapsed\":false,\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":0},\"id\":98,\"panels\":[],\"title\":\"Cluster Basic\",\"type\":\"row\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"percentage\",\"steps\":[{\"color\":\"green\",\"value\":null}]},\"unit\":\"s\"},\"overrides\":[]},\"gridPos\":{\"h\":5,\"w\":3,\"x\":0,\"y\":1},\"id\":1,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"auto\",\"reduceOptions\":{\"calcs\":[\"mean\"],\"fields\":\"\",\"values\":false},\"text\":{},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"exemplar\":true,\"expr\":\"time() - min(minio_node_process_starttime_seconds{namespace=\\\"$namespace\\\",job=\\\"$job\\\"})\",\"format\":\"time_series\",\"instant\":true,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{instance}}\",\"metric\":\"process_start_time_seconds\",\"refId\":\"A\",\"step\":60}],\"title\":\"Uptime\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"description\":\"Time elapsed since last scan activity. This is set to 0 until first scan cycle.\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null}]},\"unit\":\"ns\"},\"overrides\":[]},\"gridPos\":{\"h\":5,\"w\":4,\"x\":3,\"y\":1},\"id\":81,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"auto\",\"reduceOptions\":{\"calcs\":[\"last\"],\"fields\":\"\",\"values\":false},\"text\":{},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"exemplar\":true,\"expr\":\"minio_usage_last_activity_nano_seconds{namespace=\\\"$namespace\\\", job=\\\"$job\\\",pod=\\\"$pod\\\"}\",\"format\":\"time_series\",\"instant\":true,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{server}}\",\"metric\":\"process_start_time_seconds\",\"refId\":\"A\",\"step\":60}],\"title\":\"Time Since Last Scan\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"description\":\"Time elapsed since last self healing activity. This is set to -1 until initial self heal\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null}]},\"unit\":\"ns\"},\"overrides\":[]},\"gridPos\":{\"h\":5,\"w\":4,\"x\":7,\"y\":1},\"id\":80,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"auto\",\"reduceOptions\":{\"calcs\":[\"last\"],\"fields\":\"\",\"values\":false},\"text\":{},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"exemplar\":true,\"expr\":\"min(minio_heal_time_last_activity_nano_seconds{namespace=\\\"$namespace\\\", job=\\\"$job\\\"})\",\"format\":\"time_series\",\"instant\":true,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{server}}\",\"metric\":\"process_start_time_seconds\",\"refId\":\"A\",\"step\":60}],\"title\":\"Time Since Last Heal\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":5,\"w\":3,\"x\":11,\"y\":1},\"id\":61,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"area\",\"justifyMode\":\"auto\",\"orientation\":\"auto\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"sum(max by (server) (minio_node_file_descriptor_open_total{namespace=\\\"$namespace\\\", job=\\\"$job\\\"}))\",\"format\":\"time_series\",\"hide\":false,\"instant\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{server}}\",\"metric\":\"process_start_time_seconds\",\"range\":true,\"refId\":\"A\",\"step\":60}],\"title\":\"Total Open FDs\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"description\":\"Total number of go routines running.\\n\\n\",\"fieldConfig\":{\"defaults\":{\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":5,\"w\":3,\"x\":14,\"y\":1},\"id\":62,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"area\",\"justifyMode\":\"auto\",\"orientation\":\"auto\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(max by (server) (minio_node_go_routine_total{namespace=\\\"$namespace\\\", job=\\\"$job\\\"}))\",\"format\":\"time_series\",\"hide\":false,\"instant\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{server}}\",\"metric\":\"process_start_time_seconds\",\"refId\":\"A\",\"step\":60}],\"title\":\"Total Goroutines\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"fieldConfig\":{\"defaults\":{\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null}]},\"unit\":\"bytes\"},\"overrides\":[]},\"gridPos\":{\"h\":5,\"w\":3,\"x\":17,\"y\":1},\"id\":68,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"area\",\"justifyMode\":\"auto\",\"orientation\":\"auto\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"exemplar\":true,\"expr\":\"sum(minio_bucket_usage_total_bytes{namespace=\\\"$namespace\\\", job=\\\"$job\\\",pod=\\\"$pod\\\"})\",\"interval\":\"\",\"legendFormat\":\"Usage\",\"refId\":\"A\"}],\"title\":\"Bucket Total Size\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"fieldConfig\":{\"defaults\":{\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":5,\"w\":3,\"x\":20,\"y\":1},\"id\":66,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"area\",\"justifyMode\":\"auto\",\"orientation\":\"auto\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"exemplar\":true,\"expr\":\"count(count by (bucket) (minio_bucket_usage_total_bytes{namespace=\\\"$namespace\\\", job=\\\"$job\\\"}))\",\"format\":\"time_series\",\"instant\":false,\"interval\":\"1m\",\"intervalFactor\":1,\"legendFormat\":\"\",\"refId\":\"A\"}],\"title\":\"Number of Buckets\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"server count\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"stepBefore\",\"lineWidth\":2,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null}]}},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":7,\"x\":0,\"y\":6},\"id\":101,\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"max(minio_cluster_nodes_offline_total{namespace=\\\"$namespace\\\", job=\\\"$job\\\"})\",\"legendFormat\":\"offline \",\"range\":true,\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"min(minio_cluster_nodes_online_total{namespace=\\\"$namespace\\\", job=\\\"$job\\\"})\",\"hide\":false,\"legendFormat\":\"online\",\"range\":true,\"refId\":\"B\"}],\"title\":\"Online/Offline Server\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"The total number of drives online/offline\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"drive count\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"stepBefore\",\"lineWidth\":2,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null}]}},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":7,\"x\":7,\"y\":6},\"id\":102,\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"max(minio_cluster_disk_offline_total{namespace=\\\"$namespace\\\", job=\\\"$job\\\"})\",\"legendFormat\":\"offline \",\"range\":true,\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"expr\":\"min(minio_cluster_disk_online_total{namespace=\\\"$namespace\\\", job=\\\"$job\\\"})\",\"hide\":false,\"legendFormat\":\"online\",\"range\":true,\"refId\":\"B\"}],\"title\":\"Online/Offline Drive\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"custom\":{\"align\":\"left\",\"displayMode\":\"auto\",\"filterable\":false,\"inspect\":false},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"bytes\"},\"overrides\":[{\"matcher\":{\"id\":\"byName\",\"options\":\"Value #A\"},\"properties\":[{\"id\":\"displayName\",\"value\":\"Total\"}]},{\"matcher\":{\"id\":\"byName\",\"options\":\"Value #B\"},\"properties\":[{\"id\":\"displayName\",\"value\":\"Usage\"}]},{\"matcher\":{\"id\":\"byName\",\"options\":\"Usage Rate\"},\"properties\":[{\"id\":\"unit\",\"value\":\"percentunit\"},{\"id\":\"mappings\",\"value\":[{\"options\":{\"from\":0.8,\"result\":{\"color\":\"red\",\"index\":0},\"to\":1},\"type\":\"range\"}]},{\"id\":\"thresholds\",\"value\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null}]}}]}]},\"gridPos\":{\"h\":8,\"w\":10,\"x\":14,\"y\":6},\"id\":50,\"interval\":\"1m\",\"links\":[],\"maxDataPoints\":100,\"options\":{\"footer\":{\"enablePagination\":false,\"fields\":[\"Value #A\",\"Value #B\"],\"reducer\":[\"sum\"],\"show\":true},\"frameIndex\":1,\"showHeader\":true,\"sortBy\":[{\"desc\":false,\"displayName\":\"pod\"}]},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"sum by (pod) (minio_cluster_capacity_usable_total_bytes{namespace=\\\"$namespace\\\", job=\\\"$job\\\"})\",\"format\":\"table\",\"hide\":false,\"instant\":true,\"interval\":\"1m\",\"legendFormat\":\"total {{pod}}\",\"range\":false,\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"sum by (pod) (minio_cluster_capacity_usable_total_bytes{namespace=\\\"$namespace\\\", job=\\\"$job\\\"}) - sum by (pod) (minio_cluster_capacity_usable_free_bytes{namespace=\\\"$namespace\\\", job=\\\"$job\\\"})\",\"format\":\"table\",\"hide\":false,\"instant\":true,\"interval\":\"1m\",\"legendFormat\":\"usage {{pod}} \",\"range\":false,\"refId\":\"B\"}],\"title\":\"Cluster Capacity\",\"transformations\":[{\"id\":\"merge\",\"options\":{}},{\"id\":\"calculateField\",\"options\":{\"alias\":\"Usage Rate\",\"binary\":{\"left\":\"Value #B\",\"operator\":\"/\",\"reducer\":\"sum\",\"right\":\"Value #A\"},\"mode\":\"binary\",\"reduce\":{\"reducer\":\"sum\"},\"replaceFields\":false}}],\"type\":\"table\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false}},\"mappings\":[],\"unit\":\"bytes\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":7,\"x\":0,\"y\":14},\"id\":99,\"options\":{\"displayLabels\":[\"percent\"],\"legend\":{\"displayMode\":\"table\",\"placement\":\"right\",\"values\":[\"value\"]},\"pieType\":\"donut\",\"reduceOptions\":{\"calcs\":[\"last\"],\"fields\":\"\",\"values\":false},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"max by (bucket) (minio_bucket_usage_total_bytes{namespace=\\\"$namespace\\\", job=\\\"$job\\\"})\",\"instant\":false,\"interval\":\"\",\"legendFormat\":\"{{bucket}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"Bucket Data Usage\",\"type\":\"piechart\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"description\":\"Total number of objects in a given bucket\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false}},\"mappings\":[],\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":7,\"x\":7,\"y\":14},\"id\":44,\"links\":[],\"maxDataPoints\":100,\"options\":{\"displayLabels\":[\"percent\"],\"legend\":{\"displayMode\":\"table\",\"placement\":\"right\",\"values\":[\"value\"]},\"pieType\":\"donut\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"max by (bucket) (minio_bucket_usage_object_total{namespace=\\\"$namespace\\\", job=\\\"$job\\\",pod=\\\"$pod\\\"})\",\"format\":\"time_series\",\"instant\":false,\"interval\":\"1m\",\"intervalFactor\":1,\"legendFormat\":\"{{bucket}}\",\"refId\":\"A\"}],\"title\":\"Number of Objects\",\"type\":\"piechart\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"continuous-GrYlRd\"},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":10,\"x\":14,\"y\":14},\"id\":52,\"links\":[],\"options\":{\"displayMode\":\"basic\",\"minVizHeight\":10,\"minVizWidth\":0,\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"mean\"],\"fields\":\"\",\"values\":false},\"showUnfilled\":true,\"text\":{}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"exemplar\":true,\"expr\":\"max by (range) (minio_bucket_objects_size_distribution{namespace=\\\"$namespace\\\", job=\\\"$job\\\"})\",\"format\":\"time_series\",\"instant\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{range}}\",\"refId\":\"A\",\"step\":300}],\"title\":\"Object size distribution\",\"type\":\"bargauge\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"fieldConfig\":{\"defaults\":{\"custom\":{\"align\":\"left\",\"displayMode\":\"auto\",\"inspect\":false},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"s\"},\"overrides\":[]},\"gridPos\":{\"h\":7,\"w\":7,\"x\":0,\"y\":22},\"id\":104,\"options\":{\"footer\":{\"fields\":\"\",\"reducer\":[\"sum\"],\"show\":false},\"showHeader\":true},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"avg by (server) (minio_node_process_uptime_seconds{namespace=\\\"admin\\\",job=\\\"minio\\\"})\",\"format\":\"table\",\"instant\":true,\"range\":false,\"refId\":\"A\"}],\"title\":\"Uptime\",\"type\":\"table\"},{\"collapsed\":true,\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":29},\"id\":96,\"panels\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":1,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"bytes\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":12,\"x\":0,\"y\":30},\"id\":65,\"links\":[],\"maxDataPoints\":100,\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum by (server) (minio_s3_traffic_received_bytes{namespace=\\\"$namespace\\\", job=\\\"$job\\\"})\",\"format\":\"time_series\",\"hide\":false,\"instant\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"__auto\",\"metric\":\"process_start_time_seconds\",\"refId\":\"A\",\"step\":60}],\"title\":\"Total S3 Traffic Inbound\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":1,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"bytes\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":12,\"x\":12,\"y\":30},\"id\":64,\"links\":[],\"maxDataPoints\":100,\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum by (server) (minio_s3_traffic_sent_bytes{namespace=\\\"$namespace\\\", job=\\\"$job\\\"})\",\"format\":\"time_series\",\"hide\":false,\"instant\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{server}}\",\"metric\":\"process_start_time_seconds\",\"refId\":\"A\",\"step\":60}],\"title\":\"Total S3 Traffic Outbound\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":1,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"binBps\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":12,\"x\":0,\"y\":38},\"id\":63,\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"exemplar\":true,\"expr\":\"sum by (server) (rate(minio_s3_traffic_received_bytes{namespace=\\\"$namespace\\\", job=\\\"$job\\\"}[$__rate_interval]))\",\"interval\":\"1m\",\"intervalFactor\":2,\"legendFormat\":\"Data Received [{{server}}]\",\"refId\":\"A\"}],\"title\":\"S3 API Data Received Rate \",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":1,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"binBps\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":12,\"x\":12,\"y\":38},\"id\":70,\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"exemplar\":true,\"expr\":\"sum by (server) (rate(minio_s3_traffic_sent_bytes{namespace=\\\"$namespace\\\", job=\\\"$job\\\"}[$__rate_interval]))\",\"interval\":\"1m\",\"intervalFactor\":2,\"legendFormat\":\"Data Sent [{{server}}]\",\"refId\":\"A\"}],\"title\":\"S3 API Data Sent Rate \",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"description\":\"Total s3 bytes received per bucket\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":5,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"smooth\",\"lineWidth\":1,\"pointSize\":2,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"always\",\"spanNulls\":true,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"decbytes\"},\"overrides\":[]},\"gridPos\":{\"h\":10,\"w\":12,\"x\":0,\"y\":46},\"id\":92,\"options\":{\"legend\":{\"calcs\":[\"last\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"editorMode\":\"code\",\"expr\":\"sum by(bucket) (minio_bucket_traffic_received_bytes{namespace=\\\"$namespace\\\", job=\\\"$job\\\"})\",\"legendFormat\":\"__auto\",\"range\":true,\"refId\":\"A\"}],\"title\":\"Bucket Traffic Received\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"description\":\"Total s3 bytes sent per bucket\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":5,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"smooth\",\"lineWidth\":1,\"pointSize\":2,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":true,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"decbytes\"},\"overrides\":[]},\"gridPos\":{\"h\":10,\"w\":12,\"x\":12,\"y\":46},\"id\":90,\"options\":{\"legend\":{\"calcs\":[\"last\"],\"displayMode\":\"table\",\"placement\":\"right\",\"sortBy\":\"Max\",\"sortDesc\":true},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"editorMode\":\"code\",\"expr\":\"sum by(bucket) (minio_bucket_traffic_sent_bytes{namespace=\\\"$namespace\\\", job=\\\"$job\\\"})\",\"legendFormat\":\"__auto\",\"range\":true,\"refId\":\"A\"}],\"title\":\"Bucket Traffic Sent\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":1,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"decimals\":2,\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"}]},\"unit\":\"reqps\"},\"overrides\":[]},\"gridPos\":{\"h\":9,\"w\":24,\"x\":0,\"y\":56},\"id\":60,\"options\":{\"legend\":{\"calcs\":[\"mean\",\"max\",\"min\"],\"displayMode\":\"table\",\"placement\":\"right\",\"sortBy\":\"Mean\",\"sortDesc\":true},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"irate(minio_s3_requests_total{namespace=\\\"$namespace\\\", job=\\\"$job\\\",pod=\\\"$pod\\\"}[$__rate_interval])\",\"interval\":\"5m\",\"intervalFactor\":2,\"legendFormat\":\"api: {{api}},  {{server}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"S3 API Request Rate\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":1,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"}]},\"unit\":\"reqps\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":24,\"x\":0,\"y\":65},\"id\":71,\"options\":{\"legend\":{\"calcs\":[\"mean\",\"max\",\"min\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"rate(minio_s3_requests_errors_total{namespace=\\\"$namespace\\\", job=\\\"$job\\\",pod=\\\"$pod\\\"}[$__rate_interval])\",\"interval\":\"5m\",\"intervalFactor\":2,\"legendFormat\":\"api:{{api}}, {{server}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"S3 API Request Error Rate\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"}]},\"unit\":\"reqps\"},\"overrides\":[{\"matcher\":{\"id\":\"byName\",\"options\":\"S3 Errors\"},\"properties\":[{\"id\":\"color\",\"value\":{\"fixedColor\":\"light-red\",\"mode\":\"fixed\"}}]},{\"matcher\":{\"id\":\"byName\",\"options\":\"S3 Requests\"},\"properties\":[{\"id\":\"color\",\"value\":{\"fixedColor\":\"light-green\",\"mode\":\"fixed\"}}]}]},\"gridPos\":{\"h\":6,\"w\":24,\"x\":0,\"y\":73},\"id\":86,\"options\":{\"legend\":{\"calcs\":[\"mean\",\"max\",\"min\"],\"displayMode\":\"table\",\"placement\":\"right\",\"sortBy\":\"Last\",\"sortDesc\":true},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"rate(minio_s3_requests_5xx_errors_total{namespace=\\\"$namespace\\\", job=\\\"$job\\\",pod=\\\"$pod\\\"}[$__rate_interval])\",\"interval\":\"5m\",\"intervalFactor\":2,\"legendFormat\":\"api:{{api}}, {{server}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"S3 API Request Error Rate (5xx)\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":1,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"}]},\"unit\":\"reqps\"},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":24,\"x\":0,\"y\":79},\"id\":88,\"options\":{\"legend\":{\"calcs\":[\"mean\",\"max\",\"min\"],\"displayMode\":\"table\",\"placement\":\"right\",\"sortBy\":\"Last\",\"sortDesc\":true},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"irate(minio_s3_requests_4xx_errors_total{namespace=\\\"$namespace\\\",job=\\\"$job\\\",pod=\\\"$pod\\\"}[$__rate_interval])\",\"interval\":\"1m\",\"intervalFactor\":2,\"legendFormat\":\"api:{{api}}, {{server}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"S3 API Request Error Rate (4xx)\",\"type\":\"timeseries\"}],\"title\":\"Network\",\"type\":\"row\"},{\"collapsed\":true,\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":30},\"id\":94,\"panels\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"description\":\"Total number of bytes received and sent among all MinIO server instances\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":1,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"}]},\"unit\":\"binBps\"},\"overrides\":[]},\"gridPos\":{\"h\":9,\"w\":24,\"x\":0,\"y\":31},\"id\":17,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"mean\",\"max\",\"min\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"exemplar\":true,\"expr\":\"rate(minio_inter_node_traffic_sent_bytes{namespace=\\\"$namespace\\\", job=\\\"$job\\\",pod=\\\"$pod\\\"}[$__rate_interval])\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"Internode Bytes Received [{{server}}]\",\"metric\":\"minio_http_requests_duration_seconds_count\",\"refId\":\"A\",\"step\":4},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"exemplar\":true,\"expr\":\"rate(minio_inter_node_traffic_received_bytes{namespace=\\\"$namespace\\\", job=\\\"$job\\\",pod=\\\"$pod\\\"}[$__rate_interval])\",\"interval\":\"\",\"legendFormat\":\"Internode Bytes Sent [{{server}}]\",\"refId\":\"B\"}],\"title\":\"Internode Data Transfer Rate\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"description\":\"Objects healed in current self healing run\\n\\nObjects scanned in current self healing run\\n\\nObjects for which healing failed in current self healing run\\n\\n\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"object count\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":1,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]}},\"overrides\":[]},\"gridPos\":{\"h\":9,\"w\":24,\"x\":0,\"y\":40},\"id\":84,\"options\":{\"legend\":{\"calcs\":[\"last\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum by (server) (minio_heal_objects_heal_total{namespace=\\\"$namespace\\\", job=\\\"$job\\\"})\",\"interval\":\"\",\"legendFormat\":\"Objects healed: {{server}}\",\"range\":true,\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum by (server) (minio_heal_objects_error_total{namespace=\\\"$namespace\\\", job=\\\"$job\\\"})\",\"hide\":false,\"interval\":\"\",\"legendFormat\":\"Heal errors: {{server}}\",\"range\":true,\"refId\":\"B\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum by (server) (minio_heal_objects_total{namespace=\\\"$namespace\\\", job=\\\"$job\\\"}) \",\"hide\":false,\"interval\":\"\",\"legendFormat\":\"Objects scanned: {{server}}\",\"range\":true,\"refId\":\"C\"}],\"title\":\"Healing\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":1,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"percentunit\"},\"overrides\":[]},\"gridPos\":{\"h\":10,\"w\":24,\"x\":0,\"y\":49},\"id\":77,\"options\":{\"legend\":{\"calcs\":[\"mean\",\"max\",\"min\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"rate(minio_node_process_cpu_total_seconds{namespace=\\\"$namespace\\\", job=\\\"$job\\\",pod=\\\"$pod\\\"}[$__rate_interval])\",\"format\":\"time_series\",\"interval\":\"\",\"legendFormat\":\"CPU Usage Rate [{{server}}]\",\"range\":true,\"refId\":\"A\"}],\"title\":\"Node CPU Usage\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":1,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"bytes\"},\"overrides\":[]},\"gridPos\":{\"h\":10,\"w\":24,\"x\":0,\"y\":59},\"id\":76,\"options\":{\"legend\":{\"calcs\":[\"mean\",\"max\",\"min\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"exemplar\":true,\"expr\":\"minio_node_process_resident_memory_bytes{namespace=\\\"$namespace\\\", job=\\\"$job\\\",pod=\\\"$pod\\\"}\",\"interval\":\"\",\"legendFormat\":\"Memory Used [{{server}}]\",\"refId\":\"A\"}],\"title\":\"Node Memory Usage\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":1,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"bytes\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":12,\"x\":0,\"y\":69},\"id\":74,\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"exemplar\":true,\"expr\":\"minio_node_disk_used_bytes{namespace=\\\"$namespace\\\", job=\\\"$job\\\",pod=\\\"$pod\\\"}\",\"format\":\"time_series\",\"instant\":false,\"interval\":\"\",\"legendFormat\":\"Used Capacity [{{server}}:{{disk}}]\",\"refId\":\"A\"}],\"title\":\"Drive Used Capacity\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":1,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":12,\"x\":12,\"y\":69},\"id\":82,\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"exemplar\":true,\"expr\":\"minio_cluster_disk_free_inodes{namespace=\\\"$namespace\\\", job=\\\"$job\\\",pod=\\\"$pod\\\"}\",\"format\":\"time_series\",\"instant\":false,\"interval\":\"\",\"legendFormat\":\"Free Inodes [{{server}}:{{disk}}]\",\"refId\":\"A\"}],\"title\":\"Drives Free Inodes\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"description\":\"Total number of read/write SysCalls to the kernel. /proc/[pid]/io syscr\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":1,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"}]},\"unit\":\"ops\"},\"overrides\":[]},\"gridPos\":{\"h\":10,\"w\":24,\"x\":0,\"y\":77},\"id\":11,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"min\",\"max\",\"logmin\"],\"displayMode\":\"table\",\"placement\":\"right\",\"sortBy\":\"Last\",\"sortDesc\":true},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"exemplar\":true,\"expr\":\"rate(minio_node_syscall_read_total{namespace=\\\"$namespace\\\", job=\\\"$job\\\",pod=\\\"$pod\\\"}[$__rate_interval])\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"Read Syscalls [{{server}}]\",\"metric\":\"process_start_time_seconds\",\"refId\":\"A\",\"step\":60},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"exemplar\":true,\"expr\":\"rate(minio_node_syscall_write_total{namespace=\\\"$namespace\\\", job=\\\"$job\\\",pod=\\\"$pod\\\"}[$__rate_interval])\",\"hide\":false,\"interval\":\"\",\"legendFormat\":\"Write Syscalls [{{server}}]\",\"refId\":\"B\"}],\"title\":\"Node Syscalls Rate\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Total number of open file descriptors by the MinIO Server process.\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":1,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]}},\"overrides\":[]},\"gridPos\":{\"h\":9,\"w\":24,\"x\":0,\"y\":87},\"id\":8,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"mean\",\"max\",\"min\"],\"displayMode\":\"table\",\"placement\":\"right\",\"sortBy\":\"Last\",\"sortDesc\":true},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"exemplar\":true,\"expr\":\"minio_node_file_descriptor_open_total{namespace=\\\"$namespace\\\", job=\\\"$job\\\",pod=\\\"$pod\\\"}\",\"interval\":\"\",\"legendFormat\":\"Open FDs [{{server}}]\",\"refId\":\"B\"}],\"title\":\"Node File Descriptors\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"description\":\"Total bytes read/write by the process from the underlying storage system including cache, /proc/[pid]/io rchar\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":1,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"binBps\"},\"overrides\":[]},\"gridPos\":{\"h\":7,\"w\":24,\"x\":0,\"y\":96},\"id\":73,\"options\":{\"legend\":{\"calcs\":[\"mean\",\"max\",\"min\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"exemplar\":true,\"expr\":\"rate(minio_node_io_rchar_bytes{namespace=\\\"$namespace\\\", job=\\\"$job\\\",pod=\\\"$pod\\\"}[$__rate_interval])\",\"format\":\"time_series\",\"instant\":false,\"interval\":\"\",\"legendFormat\":\"Node RChar [{{server}}]\",\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"exemplar\":true,\"expr\":\"rate(minio_node_io_wchar_bytes{namespace=\\\"$namespace\\\", job=\\\"$job\\\",pod=\\\"$pod\\\"}[$__rate_interval])\",\"interval\":\"\",\"legendFormat\":\"Node WChar [{{server}}]\",\"refId\":\"B\"}],\"title\":\"Node IO Rate\",\"type\":\"timeseries\"}],\"title\":\"Node\",\"type\":\"row\"}],\"refresh\":false,\"schemaVersion\":36,\"style\":\"dark\",\"tags\":[\"minio\"],\"templating\":{\"list\":[{\"current\":{\"selected\":false,\"text\":\"Prometheus\",\"value\":\"Prometheus\"},\"hide\":0,\"includeAll\":false,\"label\":\"Prometheus\",\"multi\":false,\"name\":\"DS_PROMETHEUS\",\"options\":[],\"query\":\"prometheus\",\"queryValue\":\"\",\"refresh\":1,\"regex\":\"\",\"skipUrlSync\":false,\"type\":\"datasource\"},{\"current\":{\"selected\":false,\"text\":\"admin\",\"value\":\"admin\"},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"definition\":\"label_values(minio_node_process_starttime_seconds, namespace)\",\"hide\":0,\"includeAll\":false,\"multi\":false,\"name\":\"namespace\",\"options\":[],\"query\":{\"query\":\"label_values(minio_node_process_starttime_seconds, namespace)\",\"refId\":\"StandardVariableQuery\"},\"refresh\":2,\"regex\":\"\",\"skipUrlSync\":false,\"sort\":0,\"type\":\"query\"},{\"current\":{\"selected\":false,\"text\":\"minio\",\"value\":\"minio\"},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"definition\":\"label_values(minio_node_process_starttime_seconds{namespace=\\\"$namespace\\\"}, job)\",\"hide\":0,\"includeAll\":false,\"multi\":false,\"name\":\"job\",\"options\":[],\"query\":{\"query\":\"label_values(minio_node_process_starttime_seconds{namespace=\\\"$namespace\\\"}, job)\",\"refId\":\"StandardVariableQuery\"},\"refresh\":2,\"regex\":\"/(.*)-headless/\",\"skipUrlSync\":false,\"sort\":0,\"type\":\"query\"},{\"current\":{\"selected\":false,\"text\":\"minio-2\",\"value\":\"minio-2\"},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${DS_PROMETHEUS}\"},\"definition\":\"label_values(minio_node_process_starttime_seconds{namespace=\\\"$namespace\\\", job=\\\"$job\\\"}, pod)\",\"hide\":2,\"includeAll\":false,\"multi\":false,\"name\":\"pod\",\"options\":[],\"query\":{\"query\":\"label_values(minio_node_process_starttime_seconds{namespace=\\\"$namespace\\\", job=\\\"$job\\\"}, pod)\",\"refId\":\"StandardVariableQuery\"},\"refresh\":2,\"regex\":\"\",\"skipUrlSync\":false,\"sort\":1,\"type\":\"query\"}]},\"time\":{\"from\":\"now-15m\",\"to\":\"now\"},\"timepicker\":{\"refresh_intervals\":[\"10s\",\"30s\",\"1m\",\"5m\",\"15m\",\"30m\",\"1h\",\"2h\",\"1d\"],\"time_options\":[\"5m\",\"15m\",\"1h\",\"6h\",\"12h\",\"24h\",\"2d\",\"7d\",\"30d\"]},\"timezone\":\"\",\"title\":\"MinIO\",\"uid\":\"minio\",\"version\":28,\"weekStart\":\"\"}"
						}
						kind: "ConfigMap"
						metadata: {
							labels: {
								app:               "grafana"
								grafana_dashboard: "1"
							}
							name:      "minio-dashboard"
							namespace: context["namespace"]
						}
					}
					type: "raw"
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
										"minio-grafana-dashboard",
									]
								}
							},
						]
					}
					type: "shared-resource"
				},
			]
		}
	}

	parameter: {
		// +ui:title=部署模式
		// +ui:description="standalone"模式仅用于测试，生产环境请使用"distributed"
		// +ui:order=1
		mode: "distributed" | "standalone"

		// +ui:title=存储配置
		// +ui:description=仅在"distributed"模式下生效
		// +ui:hidden={{rootFormData.mode == "standalone"}}
		// +ui:order=2
		persistence: {
			// +ui:hidden=true
			enabled: *true | bool
			// +ui:description=每个节点的存储大小，请提前规划。可以增大存储大小，不支持减小存储大小。
			// +pattern=^([1-9]\d*)(Ti|Gi|Mi)$
			// +err:options={"pattern":"请输入正确格式，如1024Mi, 1Gi, 1Ti"}
			size: *"1Gi" | string
		}

		// +ui:title=节点配置
		// +ui:description=仅在"distributed"模式下生效
		// +ui:hidden={{rootFormData.mode == "standalone"}}
		// +ui:order=3
		statefulset: {
			// +minimum=4
			// +ui:description=每个Zone节点数量，生产环境至少4个节点。注意：发布后请不要修改副本数，请提前规划。 
			replicaCount: *4 | int

			// minimum=1
			// +ui:description=Zone数量，水平扩容时请增加Zone数量，不支持减少Zone数量。注意：不要随意修改Zone数量。
			zones: *1 | int
		}

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

		// +ui:title=管理员账号
		// +ui:order=7
		auth: {
			// +ui:description=管理员账号
			// +ui:options={"showPassword":true}
			rootUser: *"admin" | string

			// +ui:description=管理员密码
			// +ui:options={"showPassword":true}
			rootPassword: *"admin.password" | string
		}
	}
}
