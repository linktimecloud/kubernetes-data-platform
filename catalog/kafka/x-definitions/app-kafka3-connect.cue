"kafka-3-connect": {
	annotations: {}
	labels: {}
	attributes: {
		"dynamicParameterMeta": [
			{
				"name":        "dependencies.kafkaCluster"
				"type":        "ContextSetting"
				"refType":     "kafka"
				"refKey":      "bootstrap_plain"
				"description": "kafka server list"
				"required":    true
			},
			{
				"name":        "dependencies.schemaRegistry"
				"type":        "ContextSetting"
				"refType":     "schema-registry"
				"refKey":      "url"
				"description": "schema-registry hostname"
				"required":    false
			},
		]
		apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "Application"
				type:       "kafka-3-connect"
			}
		}
	}
	description: "kakfa connect 3 xdefinition"
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
					"properties": {
						"apiVersion": "kafka.strimzi.io/v1beta2"
						"kind":       "KafkaConnect"
						"metadata": {
							"name":      context.name
							"namespace": context.namespace
							"labels": {
								"app": context.name
							}
						}
						"spec": {
							"replicas": parameter.replicas
							"image":    context["docker_registry"] + "/" + parameter.image
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
							"bootstrapServers": parameter.dependencies.kafkaCluster
							"readinessProbe": {
								"initialDelaySeconds": 60
								"timeoutSeconds":      10
							}
							"livenessProbe": {
								"initialDelaySeconds": 60
								"timeoutSeconds":      10
							}
							"jvmOptions": {
								"-XX": {
									"MaxRAMPercentage":    85
									"UseContainerSupport": true
								}
							}
							if parameter.enableMetrics {
								"metricsConfig": {
									"type": "jmxPrometheusExporter"
									"valueFrom": {
										"configMapKeyRef": {
											"key":  "metrics-config.yml"
											"name": "connect-metrics"
										}
									}
								}
							}
							"config": {
								"group.id":             context.name + "-con-cluster"
								"offset.storage.topic": context.name + "-con-offsets"
								"config.storage.topic": context.name + "-con-configs"
								"status.storage.topic": context.name + "-con-status"
								if parameter.config != _|_ {
									for k, v in parameter.config {
										"\(k)": v
									}
								}
								if parameter.dependencies.schemaRegistry != _|_ {
									"key.converter":                           "org.apache.kafka.connect.storage.StringConverter"
									"key.converter.schema.registry.url":       parameter.dependencies.schemaRegistry
									"value.converter":                         "io.confluent.connect.avro.AvroConverter"
									"value.converter.schema.registry.url":     parameter.dependencies.schemaRegistry
									"key.converter.schemas.enable":            false
									"value.converter.schemas.enable":          true
									"internal.key.converter":                  "org.apache.kafka.connect.json.JsonConverter"
									"internal.value.converter":                "org.apache.kafka.connect.json.JsonConverter"
									"internal.key.converter.schemas.enable":   false
									"internal.value.converter.schemas.enable": false
								}
								"config.action.reload": "none"
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
									"app": context["name"]
								}
								"monitortype": "pod"
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
												"alert": context["namespace"] + "-" + context["name"] + "-connector-failed"
												"annotations": {
													"description": "There are {{ $value }} connector failed on namespace {{ $labels.namespace }} pod {{ $labels.pod }}"
													"summary":     "Kafka connector task failed"
												}
												"duration": "5m"
												"expr":     "sum(kafka_connect_connector_status{status=\"failed\"}) by (namespace,pod) \u003e 0"
												"labels": {
													"severity": "warning"
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
									"kafka-connect-dashboard.json": "{\"annotations\":{\"list\":[{\"builtIn\":1,\"datasource\":{\"type\":\"datasource\",\"uid\":\"grafana\"},\"enable\":true,\"hide\":true,\"iconColor\":\"rgba(0, 211, 255, 1)\",\"name\":\"Annotations \u0026 Alerts\",\"target\":{\"limit\":100,\"matchAny\":false,\"tags\":[],\"type\":\"dashboard\"},\"type\":\"dashboard\"}]},\"editable\":true,\"fiscalYearStartMonth\":0,\"graphTooltip\":0,\"id\":61,\"links\":[],\"liveNow\":false,\"panels\":[{\"collapsed\":false,\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":0},\"id\":1,\"panels\":[],\"title\":\"Overview\",\"type\":\"row\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null}]},\"unit\":\"none\"},\"overrides\":[]},\"gridPos\":{\"h\":7,\"w\":4,\"x\":0,\"y\":1},\"id\":130,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"none\",\"graphMode\":\"area\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"count(group(kafka_connect_worker_connector_count)by(pod))\",\"format\":\"time_series\",\"instant\":false,\"intervalFactor\":2,\"range\":true,\"refId\":\"A\",\"step\":40}],\"title\":\"Number of Connects\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null}]},\"unit\":\"none\"},\"overrides\":[]},\"gridPos\":{\"h\":7,\"w\":4,\"x\":4,\"y\":1},\"id\":2,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"none\",\"graphMode\":\"area\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"sum(kafka_connect_worker_connector_count{namespace=~\\\"$namespace\\\",job=~\\\"$cluster_name\\\"})\",\"format\":\"time_series\",\"intervalFactor\":2,\"refId\":\"A\",\"step\":40}],\"title\":\"Number of Connectors\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"none\"},\"overrides\":[]},\"gridPos\":{\"h\":7,\"w\":4,\"x\":8,\"y\":1},\"id\":3,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"none\",\"graphMode\":\"area\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"sum(kafka_connect_worker_task_count{namespace=~\\\"$namespace\\\",job=~\\\"$cluster_name\\\"})\",\"format\":\"time_series\",\"intervalFactor\":2,\"refId\":\"A\",\"step\":40}],\"title\":\"Number of Tasks\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"Bytes/sec\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"normal\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"min\":0,\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"Bps\"},\"overrides\":[]},\"gridPos\":{\"h\":7,\"w\":6,\"x\":12,\"y\":1},\"id\":4,\"links\":[],\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"sum(rate(kafka_consumer_incoming_byte_total{namespace=~\\\"$namespace\\\",job=~\\\"$cluster_name\\\",pod=~\\\"$connect\\\"}[1m])) by (pod)\",\"interval\":\"\",\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"(Sink/Consumers) Incoming bytes per second\",\"type\":\"timeseries\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":6,\"x\":18,\"y\":1},\"hiddenSeries\":false,\"id\":5,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":true,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"sum(rate(kafka_producer_outgoing_byte_total{namespace=~\\\"$namespace\\\",job=~\\\"$cluster_name\\\",pod=~\\\"$connect\\\"}[1m])) by (pod)\",\"interval\":\"\",\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"(Source/Producers) Outgoing bytes per second\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:989\",\"format\":\"Bps\",\"label\":\"Bytes/sec\",\"logBase\":1,\"min\":\"0\",\"show\":true},{\"$$hashKey\":\"object:990\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":0,\"y\":8},\"hiddenSeries\":false,\"id\":6,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"span\":4,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"sum(rate(container_cpu_usage_seconds_total{namespace=~\\\"$namespace\\\",container=~\\\".*-connect\\\",pod=~\\\"$connect\\\"}[5m])) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"metric\":\"\",\"refId\":\"A\",\"step\":4}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"CPU Usage\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:170\",\"format\":\"short\",\"label\":\"Cores\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:171\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"unit\":\"decbytes\"},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":12,\"y\":8},\"hiddenSeries\":false,\"id\":129,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"span\":4,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"sum(container_memory_usage_bytes{namespace=\\\"$namespace\\\",pod=~\\\"$connect\\\",container=~\\\".*-connect\\\"}) by (pod)\",\"hide\":false,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"B\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Memory Usage\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:170\",\"format\":\"decbytes\",\"label\":\"Cores\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:171\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"collapsed\":false,\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":15},\"id\":15,\"panels\":[],\"title\":\"Connector\",\"type\":\"row\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"custom\":{\"align\":\"left\",\"displayMode\":\"color-text\",\"filterable\":false,\"inspect\":false},\"mappings\":[{\"options\":{\"failed\":{\"color\":\"red\",\"index\":0,\"text\":\"failed\"},\"success\":{\"color\":\"green\",\"index\":1,\"text\":\"success\"}},\"type\":\"value\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null}]}},\"overrides\":[{\"matcher\":{\"id\":\"byName\",\"options\":\"status\"},\"properties\":[{\"id\":\"custom.displayMode\",\"value\":\"color-background\"}]},{\"matcher\":{\"id\":\"byName\",\"options\":\"Connector\"},\"properties\":[{\"id\":\"color\",\"value\":{\"fixedColor\":\"text\",\"mode\":\"fixed\"}}]},{\"matcher\":{\"id\":\"byName\",\"options\":\"Time\"},\"properties\":[{\"id\":\"color\",\"value\":{\"fixedColor\":\"text\",\"mode\":\"fixed\"}}]}]},\"gridPos\":{\"h\":8,\"w\":12,\"x\":0,\"y\":16},\"id\":13,\"options\":{\"footer\":{\"enablePagination\":false,\"fields\":\"\",\"reducer\":[\"sum\"],\"show\":false},\"frameIndex\":1,\"showHeader\":true,\"sortBy\":[{\"desc\":true,\"displayName\":\"Value #A\"}]},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"count by (status, connector) (kafka_connect_connector_status{namespace=~\\\"$namespace\\\",job=~\\\"$cluster_name\\\"})\",\"format\":\"table\",\"instant\":true,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"\",\"range\":false,\"refId\":\"A\"}],\"title\":\"Connector Status\",\"transformations\":[{\"id\":\"filterFieldsByName\",\"options\":{\"include\":{\"names\":[\"Time\",\"connector\",\"status\",\"connector_version\"]}}},{\"id\":\"organize\",\"options\":{\"excludeByName\":{},\"indexByName\":{\"Time\":2,\"connector\":0,\"status\":1},\"renameByName\":{\"Time\":\"updata time\",\"connector\":\"\"}}}],\"type\":\"table\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"custom\":{\"align\":\"auto\",\"displayMode\":\"auto\",\"inspect\":false},\"mappings\":[{\"options\":{\"failed\":{\"color\":\"red\",\"index\":0,\"text\":\"failed\"},\"success\":{\"color\":\"green\",\"index\":1,\"text\":\"success\"}},\"type\":\"value\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]}},\"overrides\":[{\"matcher\":{\"id\":\"byName\",\"options\":\"status\"},\"properties\":[{\"id\":\"custom.displayMode\",\"value\":\"color-background\"}]}]},\"gridPos\":{\"h\":8,\"w\":12,\"x\":12,\"y\":16},\"id\":14,\"options\":{\"footer\":{\"fields\":\"\",\"reducer\":[\"sum\"],\"show\":false},\"showHeader\":true},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"count by (connector, task, status) (kafka_connect_connector_task_status{namespace=~\\\"$namespace\\\",job=~\\\"$cluster_name\\\"})\",\"format\":\"table\",\"instant\":true,\"interval\":\"\",\"legendFormat\":\"\",\"refId\":\"A\"}],\"title\":\"Connector Task Status\",\"transformations\":[{\"id\":\"filterFieldsByName\",\"options\":{\"include\":{\"names\":[\"Time\",\"connector\",\"status\",\"task\"]}}},{\"id\":\"organize\",\"options\":{\"excludeByName\":{},\"indexByName\":{\"Time\":3,\"connector\":0,\"status\":2,\"task\":1},\"renameByName\":{\"Time\":\"Update Time\",\"connector\":\"Connector\",\"status\":\"Status\",\"task\":\"Task\"}}}],\"type\":\"table\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":8,\"x\":0,\"y\":24},\"hiddenSeries\":false,\"id\":11,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":false,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":2,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"sum(kafka_consumer_connection_count{namespace=~\\\"$namespace\\\",job=~\\\"$cluster_name\\\"})\",\"hide\":false,\"interval\":\"\",\"legendFormat\":\"consumer connections\",\"range\":true,\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"sum(kafka_producer_connection_count{namespace=~\\\"$namespace\\\",job=~\\\"$cluster_name\\\"})\",\"interval\":\"\",\"legendFormat\":\"producer connections\",\"range\":true,\"refId\":\"B\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Connection count\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"decimals\":0,\"format\":\"short\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"unit\":\"decbytes\"},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":8,\"x\":8,\"y\":24},\"hiddenSeries\":false,\"id\":131,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":2,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"sum(rate(kafka_producer_outgoing_byte_total{namespace=~\\\"$namespace\\\",job=~\\\"$cluster_name\\\"}[1m]))by(clientid)\",\"interval\":\"\",\"legendFormat\":\"{{clientid}}\",\"range\":true,\"refId\":\"B\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Producer outgoing bytes per second\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"decimals\":0,\"format\":\"decbytes\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"unit\":\"decbytes\"},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":8,\"x\":16,\"y\":24},\"hiddenSeries\":false,\"id\":132,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":2,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"sum(rate(kafka_consumer_incoming_byte_total{namespace=~\\\"$namespace\\\",job=~\\\"$cluster_name\\\"}[1m]))by(clientid)\",\"interval\":\"\",\"legendFormat\":\"{{clientid}}\",\"range\":true,\"refId\":\"B\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Consumer outgoing bytes per second\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"decimals\":0,\"format\":\"decbytes\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"collapsed\":false,\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":31},\"id\":16,\"panels\":[],\"title\":\"JVM\",\"type\":\"row\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":12,\"x\":0,\"y\":32},\"hiddenSeries\":false,\"id\":17,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[{\"$$hashKey\":\"object:1367\",\"alias\":\"{{pod}} useage percent\",\"lines\":true,\"yaxis\":1}],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(jvm_memory_bytes_used{namespace=\\\"$namespace\\\",container=~\\\".*connect.*\\\",pod=~\\\"$connect\\\"}) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}} useage\",\"range\":true,\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"sum(jvm_memory_bytes_max{namespace=\\\"$namespace\\\",container=~\\\".*connect.*\\\",pod=~\\\"$connect\\\"})by(pod)\",\"hide\":true,\"legendFormat\":\"{{pod}} limit\",\"range\":true,\"refId\":\"B\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"JVM Memory Used\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1324\",\"format\":\"decbytes\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1325\",\"format\":\"percent\",\"label\":\"Usage Percentage\",\"logBase\":1,\"max\":\"1\",\"min\":\"0\",\"show\":false}],\"yaxis\":{\"align\":true}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"JVM thread count\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":6,\"x\":12,\"y\":32},\"hiddenSeries\":false,\"id\":126,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(jvm_classes_currently_loaded{namespace=\\\"$namespace\\\",container=~\\\".*connect.*\\\",pod=~\\\"$connect\\\"})by(pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"JVM Class loaded\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1665\",\"format\":\"short\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1666\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"JVM thread count\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]}},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":6,\"x\":18,\"y\":32},\"id\":125,\"links\":[],\"options\":{\"colorMode\":\"value\",\"graphMode\":\"area\",\"justifyMode\":\"auto\",\"orientation\":\"auto\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"/^version$/\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"jvm_info{namespace=\\\"$namespace\\\",container=~\\\".*connect.*\\\",pod=~\\\"$connect\\\"}\",\"format\":\"table\",\"instant\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"Java version\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"JVM thread count\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]}},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":6,\"x\":18,\"y\":36},\"id\":124,\"links\":[],\"options\":{\"colorMode\":\"value\",\"graphMode\":\"area\",\"justifyMode\":\"auto\",\"orientation\":\"auto\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"/^jdk$/\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"label_join(jvm_info{namespace=\\\"$namespace\\\",container=~\\\".*connect.*\\\",pod=~\\\"$connect\\\"}, \\\"jdk\\\", \\\", \\\", \\\"vendor\\\", \\\"runtime\\\")\",\"format\":\"table\",\"instant\":true,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":false,\"refId\":\"A\"}],\"title\":\"JVM runtime\",\"type\":\"stat\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":6,\"x\":0,\"y\":40},\"hiddenSeries\":false,\"id\":122,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(jvm_memory_bytes_used{namespace=\\\"$namespace\\\",container=~\\\".*connect.*\\\",pod=~\\\"$connect\\\",area=\\\"heap\\\"}) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"\",\"hide\":false,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"B\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Heap Memory Used\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1271\",\"format\":\"decbytes\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1272\",\"format\":\"percent\",\"logBase\":1,\"max\":\"1\",\"min\":\"0\",\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":6,\"x\":6,\"y\":40},\"hiddenSeries\":false,\"id\":123,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":false,\"max\":true,\"min\":true,\"rightSide\":false,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(jvm_memory_bytes_used{namespace=\\\"$namespace\\\",container=~\\\".*connect.*\\\",pod=~\\\"$connect\\\",area=\\\"nonheap\\\"}) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"NonHeap Memory Used\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:163\",\"decimals\":2,\"format\":\"decbytes\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:164\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"JVM thread count\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":6,\"x\":12,\"y\":40},\"hiddenSeries\":false,\"id\":116,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(jvm_threads_current{namespace=\\\"$namespace\\\",container=~\\\".*connect.*\\\",pod=~\\\"$connect\\\"})by(pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"JVM Thread Count\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:294\",\"format\":\"short\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:295\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"JVM thread count\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":6,\"x\":18,\"y\":40},\"hiddenSeries\":false,\"id\":127,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"sum(jvm_threads_state{namespace=\\\"$namespace\\\",container=~\\\".*connect.*\\\",pod=~\\\"$connect\\\"})by(pod,state)\",\"format\":\"time_series\",\"instant\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}} {{state}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"JVM Thread State\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1730\",\"format\":\"short\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1731\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":0,\"y\":48},\"hiddenSeries\":false,\"id\":95,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(increase(jvm_gc_collection_seconds_count{namespace=\\\"$namespace\\\",container=~\\\".*connect.*\\\",pod=~\\\"$connect\\\"}[1m])) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}} {{gc}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"JVM GC Count\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1535\",\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1536\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":12,\"y\":48},\"hiddenSeries\":false,\"id\":113,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(increase(jvm_gc_collection_seconds_sum{namespace=\\\"$namespace\\\",container=~\\\".*connect.*\\\",pod=~\\\"$connect\\\"}[1m])) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}} {{gc}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"JVM GC Time\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"ms\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":6,\"x\":0,\"y\":55},\"hiddenSeries\":false,\"id\":97,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"sum(increase(jvm_gc_collection_seconds_count{namespace=\\\"$namespace\\\",container=~\\\".*connect.*\\\",pod=~\\\"$connect\\\",gc=~\\\"Copy|G1 Young Generation\\\"}[1m])) by (pod)\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}} {{gc}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Young GC Count\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1474\",\"format\":\"short\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1475\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":6,\"x\":6,\"y\":55},\"hiddenSeries\":false,\"id\":114,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"sum(increase(jvm_gc_collection_seconds_count{namespace=\\\"$namespace\\\",container=~\\\".*connect.*\\\",pod=~\\\"$connect\\\",gc=~\\\"MarkSweepCompact|G1 Old.*\\\"}[1m])) by (pod)\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}} {{gc}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Old GC Count\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"short\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":6,\"x\":12,\"y\":55},\"hiddenSeries\":false,\"id\":117,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(increase(jvm_gc_collection_seconds_sum{namespace=\\\"$namespace\\\",container=~\\\".*connect.*\\\",pod=~\\\"$connect\\\",gc=~\\\"Copy|G1 Young Generation\\\"}[1m])) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}} {{gc}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Young GC Time\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:163\",\"format\":\"ms\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:164\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":6,\"x\":18,\"y\":55},\"hiddenSeries\":false,\"id\":128,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(increase(jvm_gc_collection_seconds_sum{namespace=\\\"$namespace\\\",container=~\\\".*connect.*\\\",pod=~\\\"$connect\\\",gc=~\\\"MarkSweepCompact|G1 Old Generation\\\"}[1m])) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}} {{gc}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Old GC Time\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:163\",\"format\":\"ms\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:164\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}}],\"refresh\":\"1m\",\"schemaVersion\":36,\"style\":\"dark\",\"tags\":[\"Strimzi\",\"Kafka\",\"Kafka Connect\"],\"templating\":{\"list\":[{\"current\":{\"selected\":false,\"text\":\"Prometheus\",\"value\":\"Prometheus\"},\"hide\":0,\"includeAll\":false,\"multi\":false,\"name\":\"datasource\",\"options\":[],\"query\":\"prometheus\",\"refresh\":1,\"regex\":\"\",\"skipUrlSync\":false,\"type\":\"datasource\"},{\"current\":{\"selected\":false,\"text\":\"admin\",\"value\":\"admin\"},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"definition\":\"query_result(kafka_connect_worker_connector_count)\",\"hide\":0,\"includeAll\":false,\"label\":\"Namespace\",\"multi\":false,\"name\":\"namespace\",\"options\":[],\"query\":{\"query\":\"query_result(kafka_connect_worker_connector_count)\",\"refId\":\"StandardVariableQuery\"},\"refresh\":1,\"regex\":\"/.*namespace=\\\"([^\\\"]+).*/\",\"skipUrlSync\":false,\"sort\":0,\"tagValuesQuery\":\"\",\"tagsQuery\":\"\",\"type\":\"query\",\"useTags\":false},{\"current\":{\"selected\":false,\"text\":\"admin/admin-kafka-connect-strimzi\",\"value\":\"admin/admin-kafka-connect-strimzi\"},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"definition\":\"query_result(kafka_connect_worker_connector_count{namespace=\\\"$namespace\\\"})\",\"hide\":0,\"includeAll\":false,\"label\":\"Cluster Name\",\"multi\":false,\"name\":\"cluster_name\",\"options\":[],\"query\":{\"query\":\"query_result(kafka_connect_worker_connector_count{namespace=\\\"$namespace\\\"})\",\"refId\":\"StandardVariableQuery\"},\"refresh\":1,\"regex\":\"/.*job=\\\"([^\\\"]+).*/\",\"skipUrlSync\":false,\"sort\":0,\"tagValuesQuery\":\"\",\"tagsQuery\":\"\",\"type\":\"query\",\"useTags\":false},{\"allValue\":\".*\",\"current\":{\"selected\":false,\"text\":\"All\",\"value\":\"$__all\"},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"definition\":\"query_result(count_over_time(kafka_connect_worker_connector_count{namespace=\\\"$namespace\\\",job=\\\"$cluster_name\\\"}[$__range]))\",\"hide\":0,\"includeAll\":true,\"label\":\"Connect\",\"multi\":false,\"name\":\"connect\",\"options\":[],\"query\":{\"query\":\"query_result(count_over_time(kafka_connect_worker_connector_count{namespace=\\\"$namespace\\\",job=\\\"$cluster_name\\\"}[$__range]))\",\"refId\":\"StandardVariableQuery\"},\"refresh\":2,\"regex\":\"/.*pod=\\\"([^\\\"]+).*/\",\"skipUrlSync\":false,\"sort\":1,\"type\":\"query\"}]},\"time\":{\"from\":\"now-1h\",\"to\":\"now\"},\"timepicker\":{\"refresh_intervals\":[\"5s\",\"10s\",\"30s\",\"1m\",\"5m\",\"15m\",\"30m\",\"1h\",\"2h\",\"1d\"],\"time_options\":[\"5m\",\"15m\",\"1h\",\"6h\",\"12h\",\"24h\",\"2d\",\"7d\",\"30d\"]},\"timezone\":\"\",\"title\":\"KDP Kafka Connect\",\"uid\":\"kdpKafkaConnect2023\",\"version\":6,\"weekStart\":\"\"}"
								}
								"labels": {
									"app":               "grafana"
									"grafana_dashboard": "1"
								}
							}
							"type": "bdos-grafana-dashboard"
						},
					]
					"type": "raw"
				},
				{
					"name": context.name + "-context"
					"type": "raw"
					"properties": {
						//生成connect地址端口相关的上下文信息
						"apiVersion": "bdc.kdp.io/v1alpha1"
						"kind":       "ContextSetting"
						"metadata": {
							"name": context.namespace + "-" + context.name + "-context"
							"annotations": {
								"setting.ctx.bdc.kdp.io/type":   "connect"
								"setting.ctx.bdc.kdp.io/origin": "system"
							}
						}
						"spec": {
							"name": context.name
							"type": "connect"
							"properties": {
								"url":  "http://" + context.name + "-connect-api." + context.namespace + "." + context.domain_suffix + ":8083"
								"host": context.name + "-connect-api." + context.namespace + "." + context.domain_suffix
								"port": "8083"
							}
						}
					}
				}
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
		// +ui:order=1
		// +ui:title=组件依赖
		dependencies: {
			// +ui:description=connect依赖kafka地址
			// +ui:order=1
			// +err:options={"required":"请先安装kafka，或添加已安装的kafka集群配置"}
			kafkaCluster: string
			// +ui:description=connect依赖schema地址
			// +ui:order=2
			// +ui:options={"clearable":true}
			schemaRegistry?: string
		}
		// +minimum=1
		// +ui:description=副本数
		// +ui:order=2
		replicas: *1 | int
		// +ui:description=资源规格
		// +ui:order=3
		resources: {
			// +ui:description=预留
			// +ui:order=1
			requests: {
				// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
				// +ui:order=1
				// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
				cpu: *"0.1" | string
				// +pattern=^[1-9]\d*(Mi|Gi)$
				// +ui:order=2
				// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
				memory: *"1024Mi" | string
			}
			// +ui:description=限制
			// +ui:order=2
			limits: {
				// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
				// +ui:order=1
				// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
				cpu: *"1" | string
				// +pattern=^[1-9]\d*(Mi|Gi)$
				// +ui:order=2
				// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
				memory: *"1024Mi" | string
			}
		}
		// +ui:description=是否开启connect监控
		// +ui:order=5
		enableMetrics: *true | bool
		// +ui:description=镜像版本
		// +ui:order=10001
		// +ui:options={"disabled":true}
		image: *"kafka/kafka-connect:v1.0.0-0.34.0-3-kafka-3.4.1" | string
	}
}
