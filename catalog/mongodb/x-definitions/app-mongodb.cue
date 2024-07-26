import "encoding/base64"

"mongodb": {
	annotations: {}
	labels: {}
	attributes: {
		dynamicParameterMeta: [
		]
		apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "Application"
				type:       "mongodb"
			}
		}
	}
	description: "mongodb"
	type:        "xdefinition"
}

template: {
	_imageRegistry: context["docker_registry"]
	_metricPort:    9216
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
					type: "helm"
					properties: {
						chart:           "mongodb-sharded"
						releaseName:     context["name"]
						repoType:        "oci"
						targetNamespace: context["namespace"]
						url:             context["helm_repo_url"]
						// https://artifacthub.io/packages/helm/bitnami/mongodb-sharded/8.3.2
						version: "8.3.2"
						values: {
							global: {
								imageRegistry: _imageRegistry
								storageClass:  context["storage_config.storage_class_mapping.local_disk"]
							}
							// authtentication
							auth: {
								enabled:      true
								rootUser:     parameter.auth.rootUser
								rootPassword: parameter.auth.rootPassword
							}
							// config server 
							configsvr: {
								replicaCount: parameter.configServer.replicaCount
								persistence: {
									enabled: true
									size:    parameter.configServer.persistence.size
								}
								resources: parameter.configServer.resources
								if parameter.affinity != _|_ {
									affinity: parameter.configServer.affinity
								}
							}
							// mongos node
							mongos: {
								replicaCount: parameter.mongos.replicaCount
								resources:    parameter.mongos.resources
								if parameter.affinity != _|_ {
									affinity: parameter.mongos.affinity
								}

							}
							// shard node
							shards: parameter.shard.shardCount
							shardsvr: {
								persistence: {
									enabled: true
									size:    parameter.shard.persistence.size
								}
								dataNode: {
									replicaCount: parameter.shard.replicaCount
									resources:    parameter.shard.resources
									if parameter.affinity != _|_ {
										affinity: parameter.shard.affinity
									}
									podLabels: {
										"app": context["name"]
									}
								}
							}
							// metrics pod https://logz.io/blog/mongodb-monitoring-prometheus-best-practices/
							metrics: {
								enabled: true
							}
						}
					}

					traits: [
						{
							type: "bdos-monitor"
							properties: {
								monitortype: "service"
								endpoints: [
									{
										port:     _metricPort
										path:     "/metrics"
										portName: "metrics"
									},
								]
								matchLabels: {
									// app.kubernetes.io/component=mongos
									"app.kubernetes.io/component": "mongos"
								}
							}
						},
						{
							type: "bdos-grafana-dashboard"
							properties: {
								labels: {
									"grafana_dashboard": "1"
								}
								dashboard_data: {
									"{\"annotations\":{\"list\":[{\"builtIn\":1,\"datasource\":{\"type\":\"grafana\",\"uid\":\"--Grafana--\"},\"enable\":true,\"hide\":true,\"iconColor\":\"rgba(0,211,255,1)\",\"name\":\"Annotations&Alerts\",\"type\":\"dashboard\"}]},\"description\":\"NoteforaofficialGrafanaMongoDBplugin,pleaseview:\\nhttps://grafana.com/grafana/plugins/grafana-mongodb-datasource\\n\\nThisisaMongoDBPrometheusExporterDashboard.\\nWorkswellwithhttps://github.com/dcu/mongodb_exporter\\n\\nIfyouhavethenode_exporterrunningonthemongoinstance,youwillalsogetsomeusefulalertpanelsrelatedtodiskioandcpu.\",\"editable\":true,\"fiscalYearStartMonth\":0,\"gnetId\":2583,\"graphTooltip\":1,\"id\":104,\"links\":[],\"liveNow\":false,\"panels\":[{\"collapsed\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":0},\"id\":20,\"panels\":[],\"repeat\":\"env\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"refId\":\"A\"}],\"title\":\"QueryMetricsfor$env\",\"type\":\"row\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":6,\"w\":10,\"x\":0,\"y\":1},\"hiddenSeries\":false,\"id\":7,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"expr\":\"rate(mongodb_op_counters_total{instance=~\\\"$env\\\"}[$interval])\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"{{type}}\",\"refId\":\"A\",\"step\":240}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"QueryOperations\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"ops\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":6,\"w\":8,\"x\":10,\"y\":1},\"hiddenSeries\":false,\"id\":9,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[{\"alias\":\"returned\",\"yaxis\":1}],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"expr\":\"rate(mongodb_metrics_document_total{instance=~\\\"$env\\\"}[$interval])\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"{{state}}\",\"refId\":\"A\",\"step\":240}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"DocumentOperations\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"short\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":6,\"w\":6,\"x\":18,\"y\":1},\"hiddenSeries\":false,\"id\":8,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"expr\":\"rate(mongodb_metrics_query_executor_total{instance=~\\\"$env\\\"}[$interval])\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"{{state}}\",\"refId\":\"A\",\"step\":600}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"DocumentQueryExecutor\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"short\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"collapsed\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":7},\"id\":21,\"panels\":[],\"repeat\":\"env\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"refId\":\"A\"}],\"title\":\"ReplicaSetMetricsfor$env\",\"type\":\"row\"},{\"aliasColors\":{},\"bars\":true,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":6,\"w\":6,\"x\":0,\"y\":8},\"hiddenSeries\":false,\"id\":15,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":false,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"expr\":\"mongodb_replset_number_of_members{instance=~\\\"$env\\\"}\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"#members\",\"refId\":\"A\",\"step\":600},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"expr\":\"sum(mongodb_replset_member_health{instance=~\\\"$env\\\"})\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"healthymembers\",\"refId\":\"B\",\"step\":600}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"MemberHealth\",\"tooltip\":{\"shared\":false,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"series\",\"show\":false,\"values\":[\"current\"]},\"yaxes\":[{\"format\":\"none\",\"logBase\":1,\"min\":\"0\",\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":true,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"description\":\"Seewhichnodeiscurrentlyactingastheprimary,secondary,...\",\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":6,\"w\":12,\"x\":6,\"y\":8},\"hiddenSeries\":false,\"id\":14,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":false,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"expr\":\"mongodb_replset_member_state{instance=~\\\"$env\\\"}\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"{{state}}-{{name}}\",\"refId\":\"A\",\"step\":240}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"MemberState\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"series\",\"show\":false,\"values\":[\"current\"]},\"yaxes\":[{\"format\":\"none\",\"label\":\"\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":6,\"w\":6,\"x\":18,\"y\":8},\"hiddenSeries\":false,\"id\":11,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"expr\":\"rate(mongodb_op_counters_repl_total{instance=~\\\"$env\\\"}[$interval])\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"{{type}}\",\"refId\":\"A\",\"step\":600}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"ReplicaQueryOperations\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"ops\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"collapsed\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":14},\"id\":22,\"panels\":[],\"repeat\":\"env\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"refId\":\"A\"}],\"title\":\"Healthmetricsfor$env\",\"type\":\"row\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"rgba(245,54,54,0.9)\",\"value\":null},{\"color\":\"rgba(237,129,40,0.89)\",\"value\":0},{\"color\":\"rgba(50,172,45,0.97)\",\"value\":360}]},\"unit\":\"s\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":4,\"x\":0,\"y\":15},\"id\":10,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"showPercentChange\":false,\"textMode\":\"auto\",\"wideLayout\":true},\"pluginVersion\":\"10.3.3\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"expr\":\"mongodb_instance_uptime_seconds{instance=~\\\"$env\\\"}\",\"format\":\"time_series\",\"intervalFactor\":2,\"legendFormat\":\"\",\"refId\":\"A\",\"step\":1800}],\"title\":\"Uptime\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"fixedColor\":\"rgb(31,120,193)\",\"mode\":\"fixed\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"none\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":4,\"x\":4,\"y\":15},\"id\":2,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"none\",\"graphMode\":\"area\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"mean\"],\"fields\":\"\",\"values\":false},\"showPercentChange\":false,\"textMode\":\"auto\",\"wideLayout\":true},\"pluginVersion\":\"10.3.3\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"expr\":\"mongodb_connections{instance=~\\\"$env\\\",state=\\\"available\\\"}\",\"format\":\"time_series\",\"intervalFactor\":2,\"legendFormat\":\"\",\"metric\":\"mongodb_connections\",\"refId\":\"A\",\"step\":1800}],\"title\":\"AvailableConnections\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"fixedColor\":\"rgb(31,120,193)\",\"mode\":\"fixed\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"none\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":16,\"x\":8,\"y\":15},\"id\":1,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"none\",\"graphMode\":\"area\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"mean\"],\"fields\":\"\",\"values\":false},\"showPercentChange\":false,\"textMode\":\"auto\",\"wideLayout\":true},\"pluginVersion\":\"10.3.3\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"expr\":\"mongodb_connections{instance=~\\\"$env\\\",state=\\\"current\\\"}\",\"format\":\"time_series\",\"intervalFactor\":2,\"legendFormat\":\"\",\"metric\":\"mongodb_connections\",\"refId\":\"A\",\"step\":1800}],\"title\":\"OpenConnections\",\"type\":\"stat\"},{\"collapsed\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":19},\"id\":23,\"panels\":[],\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"refId\":\"A\"}],\"title\":\"ResourceMetrics\",\"type\":\"row\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":6,\"w\":8,\"x\":0,\"y\":20},\"hiddenSeries\":false,\"id\":6,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"expr\":\"mongodb_replset_oplog_size_bytes{instance=~\\\"$env\\\"}\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"{{type}}\",\"metric\":\"mongodb_locks_time_acquiring_global_microseconds_total\",\"refId\":\"A\",\"step\":240}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"OplogSize\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"decbytes\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":6,\"w\":8,\"x\":8,\"y\":20},\"hiddenSeries\":false,\"id\":4,\"legend\":{\"alignAsTable\":false,\"avg\":false,\"current\":true,\"hideEmpty\":false,\"hideZero\":false,\"max\":false,\"min\":false,\"rightSide\":false,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"expr\":\"mongodb_memory{instance=~\\\"$env\\\",type=~\\\"resident|virtual\\\"}\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"{{type}}\",\"refId\":\"A\",\"step\":240}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Memory\",\"tooltip\":{\"shared\":false,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[\"total\"]},\"yaxes\":[{\"format\":\"decmbytes\",\"label\":\"MB\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":6,\"w\":8,\"x\":16,\"y\":20},\"hiddenSeries\":false,\"id\":5,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"expr\":\"rate(mongodb_network_bytes_total{instance=~\\\"$env\\\"}[$interval])\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"{{state}}\",\"metric\":\"mongodb_metrics_operation_total\",\"refId\":\"A\",\"step\":240}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"NetworkI/O\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"decbytes\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"collapsed\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":26},\"id\":24,\"panels\":[],\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"refId\":\"A\"}],\"title\":\"Alerts\",\"type\":\"row\"},{\"alert\":{\"conditions\":[{\"evaluator\":{\"params\":[300],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[\"A\",\"15m\",\"now\"]},\"reducer\":{\"params\":[],\"type\":\"avg\"},\"type\":\"query\"}],\"executionErrorState\":\"keep_state\",\"frequency\":\"60s\",\"handler\":1,\"message\":\"AMongoDBoplogreplicationhasbeen5minutesbehindinitsreplicationformorethan15minutes.\\nBeingabletofailovertoareplicaofyourdataisonlyusefulifthedataisuptodate,soyouneedtoknowwhenthat’snolongerthecase!\",\"name\":\"MongoDBOploglagalert\",\"noDataState\":\"no_data\",\"notifications\":[{\"id\":2}]},\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":0,\"y\":27},\"hiddenSeries\":false,\"id\":16,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":false,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"expr\":\"rate(mongodb_replset_oplog_head_timestamp[5m])\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"{{instance}}\",\"refId\":\"A\",\"step\":240}],\"thresholds\":[{\"colorMode\":\"critical\",\"fill\":true,\"line\":true,\"op\":\"gt\",\"value\":300}],\"timeRegions\":[],\"title\":\"OplogLag\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"dtdurations\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"alert\":{\"conditions\":[{\"evaluator\":{\"params\":[0.98],\"type\":\"gt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[\"A\",\"5m\",\"now\"]},\"reducer\":{\"params\":[],\"type\":\"avg\"},\"type\":\"query\"}],\"executionErrorState\":\"keep_state\",\"frequency\":\"60s\",\"handler\":1,\"message\":\"MongoDB'saveragediski/outilizationhasbeenabove98%for5minutes\",\"name\":\"MongoDB'sDiskIOUtilizationalert\",\"noDataState\":\"no_data\",\"notifications\":[{\"id\":2}]},\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":12,\"y\":27},\"hiddenSeries\":false,\"id\":17,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"rightSide\":true,\"show\":false,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"expr\":\"(rate(node_disk_io_time_ms{instance=~\\\"shr.*\\\"}[5m])/1000orirate(node_disk_io_time_ms{instance=~\\\"shr.*\\\"}[5m])/1000)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"{{device}}-{{instance}}\",\"refId\":\"A\",\"step\":240}],\"thresholds\":[{\"colorMode\":\"critical\",\"fill\":true,\"line\":true,\"op\":\"gt\",\"value\":0.98}],\"timeRegions\":[],\"title\":\"DiskIOUtilization\",\"tooltip\":{\"shared\":false,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"percentunit\",\"label\":\"\",\"logBase\":1,\"max\":\"1\",\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"collapsed\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":34},\"id\":25,\"panels\":[],\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"refId\":\"A\"}],\"title\":\"DashboardRow\",\"type\":\"row\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":0,\"y\":35},\"hiddenSeries\":false,\"id\":18,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":false,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"expr\":\"rate(node_disk_reads_completed{instance=~\\\"shr.*\\\"}[5m])\",\"format\":\"time_series\",\"intervalFactor\":2,\"legendFormat\":\"{{device}}-{{instance}}\",\"refId\":\"A\",\"step\":240}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"DiskReadsCompleted\",\"tooltip\":{\"shared\":false,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"short\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":12,\"y\":35},\"hiddenSeries\":false,\"id\":19,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":false,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"expr\":\"rate(node_disk_writes_completed{instance=~\\\"shr.*\\\"}[5m])\",\"format\":\"time_series\",\"intervalFactor\":2,\"legendFormat\":\"{{device}}-{{instance}}\",\"refId\":\"A\",\"step\":240}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"DiskWritesCompleted\",\"tooltip\":{\"shared\":false,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"short\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}}],\"refresh\":\"5s\",\"schemaVersion\":39,\"tags\":[\"prometheus\"],\"templating\":{\"list\":[{\"current\":{\"selected\":true,\"text\":[\"10.42.2.228:9216\"],\"value\":[\"10.42.2.228:9216\"]},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"definition\":\"\",\"hide\":0,\"includeAll\":true,\"label\":\"env\",\"multi\":true,\"name\":\"env\",\"options\":[],\"query\":\"label_values(mongodb_connections,instance)\",\"refresh\":1,\"regex\":\"\",\"skipUrlSync\":false,\"sort\":1,\"type\":\"query\",\"useTags\":false},{\"auto\":true,\"auto_count\":30,\"auto_min\":\"10s\",\"current\":{\"selected\":false,\"text\":\"auto\",\"value\":\"$__auto_interval_interval\"},\"hide\":0,\"name\":\"interval\",\"options\":[{\"selected\":true,\"text\":\"auto\",\"value\":\"$__auto_interval_interval\"},{\"selected\":false,\"text\":\"1m\",\"value\":\"1m\"},{\"selected\":false,\"text\":\"10m\",\"value\":\"10m\"},{\"selected\":false,\"text\":\"30m\",\"value\":\"30m\"},{\"selected\":false,\"text\":\"1h\",\"value\":\"1h\"},{\"selected\":false,\"text\":\"6h\",\"value\":\"6h\"},{\"selected\":false,\"text\":\"12h\",\"value\":\"12h\"},{\"selected\":false,\"text\":\"1d\",\"value\":\"1d\"},{\"selected\":false,\"text\":\"7d\",\"value\":\"7d\"},{\"selected\":false,\"text\":\"14d\",\"value\":\"14d\"},{\"selected\":false,\"text\":\"30d\",\"value\":\"30d\"}],\"query\":\"1m,10m,30m,1h,6h,12h,1d,7d,14d,30d\",\"refresh\":2,\"skipUrlSync\":false,\"type\":\"interval\"}]},\"time\":{\"from\":\"now/d\",\"to\":\"now\"},\"timepicker\":{\"refresh_intervals\":[\"5s\",\"10s\",\"30s\",\"1m\",\"5m\",\"15m\",\"30m\",\"1h\",\"2h\",\"1d\"],\"time_options\":[\"5m\",\"15m\",\"1h\",\"6h\",\"12h\",\"24h\",\"2d\",\"7d\",\"30d\"]},\"timezone\":\"browser\",\"title\":\"MongoDBDashboard\",\"uid\":\"mongodb\",\"version\":1,\"weekStart\":\"\"}"
								}
							}
						},
					]
				},
				{
					name: context["name"] + "-context"
					type: "k8s-objects"
					properties: {
						objects: [
							{
								apiVersion: "bdc.kdp.io/v1alpha1"
								kind:       "ContextSetting"
								metadata: {
									annotations: {
										"setting.ctx.bdc.kdp.io/origin": "system"
										"setting.ctx.bdc.kdp.io/type":   "mongodb"
									}
									name:      context["namespace"] + "-" + context["name"] + "-context-setting"
									namespace: context["namespace"]
								}
								spec: {
									name:      context["name"] + "-context-setting"
									_port:     "27017"
									_hostname: context["name"] + "." + context["namespace"] + ".svc.cluster.local"
									properties: {
										hostname: _hostname
										port:     _port
										host:     _hostname + ":" + _port
									}
									type: "mongodb"
								}
							},
							{
								apiVersion: "bdc.kdp.io/v1alpha1"
								kind:       "ContextSecret"
								metadata: {
									annotations: {
										"setting.ctx.bdc.kdp.io/origin": "system"
										"setting.ctx.bdc.kdp.io/type":   "mongodb"
									}
									name:      context["namespace"] + "-" + context["name"] + "-context-secret"
									namespace: context["namespace"]
								}
								spec: {
									name: context["name"] + "-context-secret"
									type: "mongodb"
									properties: {
										"MONGODB_ROOT_USER":     base64.Encode(null, parameter.auth.rootUser)
										"MONGODB_ROOT_PASSWORD": base64.Encode(null, parameter.auth.rootPassword)
									}
								}
							},
							
						]
					}
				},
			]
			policies: []
		}
	}

	parameter: {
		// +ui:title=config service 配置
		// +ui:order=1
		configServer: {
			// +minimum=1
			// +ui:description=master 节点数量, 高可用场景建议配置3个
			// +ui:order=1
			replicaCount: *1 | int

			// +ui:title=存储配置
			// +ui:order=2
			persistence: {
				// pattern=^[1-9]\d*(Gi|Mi|Ti)$
				// err:options={"pattern":"请输入正确格式，如1024Mi, 1Gi, 1Ti"}
				// +ui:description=各节点存储大小，请根据实际情况调整
				// +ui:order=2
				// +ui:hidden={{rootFormData.master.persistence.enabled == false}}
				size: *"1Gi" | string
			}

			// +ui:description=资源规格
			// +ui:order=3
			resources: {
				// +ui:description=预留
				// +ui:order=1
				requests: {
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的CPU格式，如0.25，250m"}
					// +ui:description=CPU
					cpu: *"25m" | string

					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入����确的内存格式，如1024Mi, 1Gi"}
					// +ui:description=内存
					memory: *"512Mi" | string
				}

				// +ui:description=限制
				// +ui:order=2
				limits: {
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的CPU格式，如0.25，250m"}
					// +ui:description=CPU
					cpu: *"2" | string

					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					// +ui:description=内存
					memory: *"1Gi" | string
				}
			}

			// +ui:description=配置kubernetes亲和性，请���据实际情况调���
			// +ui:order=4
			affinity?: {}
		}

		// +ui:title=mongos 配置
		// +ui:order=2
		mongos: {
			// +minimum=1
			// +ui:description=master 节点数量, 高可用场景建议配置2个起
			// +ui:order=1
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
					cpu: *"25m" | string

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
					cpu: *"2" | string

					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					// +ui:description=内存
					memory: *"1Gi" | string
				}
			}

			// +ui:description=配置kubernetes亲和性，请根据实际情况调整
			// +ui:order=4
			affinity?: {}

		}

		// +ui:title=shard 配置
		// +ui:order=2
		shard: {
			// +minimum=1
			// +ui:description=shard 数量，按需配置
			// +ui:order=1
			shardCount: *1 | int

			// +minimum=1
			// +ui:description=master 节点数量, 高可用场景建议配置3个
			// +ui:order=2
			replicaCount: *1 | int

			// +ui:title=存储配置
			// +ui:order=3
			persistence: {
				// pattern=^[1-9]\d*(Gi|Mi|Ti)$
				// err:options={"pattern":"请输入正确格式，如1024Mi, 1Gi, 1Ti"}
				// +ui:description=各节点存储大小，请根据实际情况调整
				// +ui:hidden={{rootFormData.master.persistence.enabled == false}}
				size: *"1Gi" | string
			}

			// +ui:description=资源规格
			// +ui:order=4
			resources: {
				// +ui:description=预留
				// +ui:order=1
				requests: {
					// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
					// +err:options={"pattern":"请输入正确的CPU格式，如0.25，250m"}
					// +ui:description=CPU
					cpu: *"25m" | string

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
					cpu: *"2" | string

					// +pattern=^[1-9]\d*(Mi|Gi)$
					// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
					// +ui:description=内存
					memory: *"1Gi" | string
				}
			}

			// +ui:description=配置kubernetes亲和性，请根据实际情况调整
			// +ui:order=5
			affinity?: {}

		}

		// +ui:title=管理员账号
		// +ui:order=7
		auth: {
			// +ui:description=管理员账号
			// +ui:options={"showPassword":true}
			rootUser: *"root" | string

			// +ui:description=管理员密码
			// +ui:options={"showPassword":true}
			rootPassword: *"root.password" | string
		}

	}
}
