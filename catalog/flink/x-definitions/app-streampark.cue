import "strings"

"streampark": {
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
				type:       "streampark"
			}
		}
	}
	description: "streampark"
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
					type: "raw"
					name: context["name"]
					properties: {
						apiVersion: "apps/v1"
						kind:       "Deployment"
						metadata: {
							annotations: {
								"app.core.bdos/catalog": "flink"
							}
							labels: {
								app:                  context.name
								"app.core.bdos/type": "system"
							}
							name:      context.name
							namespace: context["namespace"]
						}
						spec: {
							selector: matchLabels: {
								app:                     context.name
								"app.oam.dev/component": context.name
							}
							replicas: parameter.replicas
							template: {
								metadata: {
									labels: {
										app:                     context.name
										"app.oam.dev/component": "streampark"
									}
								}
								spec: {
									containers: [{
										name: context.name
										if parameter.resources != _|_ {
											resources: parameter.resources
										}
										env: [
											{
												name:  "TZ"
												value: "Asia/Shanghai"
											},
											{
												name:  "SPRING_PROFILES_ACTIVE"
												value: "mysql"
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
											{
												name:  "SPRING_DATASOURCE_URL"
												value: "jdbc:mysql://$(MYSQL_HOST):$(MYSQL_PORT)/" + "\(strings.Replace(context.namespace+"_streampark", "-", "_", -1))" + "?useUnicode=true&characterEncoding=utf8&serverTimezone=GMT%2B8"
											},
											{
												name: "SPRING_DATASOURCE_PASSWORD"
												valueFrom: {
													secretKeyRef: {
														key:  "MYSQL_PASSWORD"
														name: "\(parameter.mysql.mysqlSecret)"
													}
												}
											},
											{
												name: "SPRING_DATASOURCE_USERNAME"
												valueFrom: {
													secretKeyRef: {
														key:  "MYSQL_USER"
														name: "\(parameter.mysql.mysqlSecret)"
													}
												}
											},
										]
										image: context["docker_registry"] + "/" + parameter.image
										volumeMounts: [{
											mountPath: "/streampark/logs"
											name:      "logs"
										}]
										livenessProbe: {
											httpGet: {
												path:   "/actuator/health/livenessState"
												port:   10000
												scheme: "HTTP"
											}
											initialDelaySeconds: 60
											periodSeconds:       10
											failureThreshold:    3
											timeoutSeconds:      3
											successThreshold:    1
										}
									}]
									restartPolicy: "Always"
									if parameter["imagePullSecrets"] != _|_ {
										imagePullSecrets: [ for v in parameter.imagePullSecrets {
											name: v
										},
										]
									}
									volumes: [{
										emptyDir: {}
										name: "logs"
									},
									]
								}
							}
						}
					}
					traits: [
						{
							properties: {
								accessModes: [
									"ReadWriteOnce",
								]
								claimName: context["name"]
								resources: {
									requests: {
										storage: "5Gi"
									}
								}
								storageClassName: context["storage_config.storage_class_mapping.local_disk"]
								volumesToMount: [
									{
										mountPath: "/streampark/streampark_workspace"
										name:      "data"
									},
								]
							}
							type: "bdos-pvc"
						},
						{
							properties: {
								accessModes: [
									"ReadWriteOnce",
								]
								claimName: context["name"] + "-temp"
								resources: {
									requests: {
										storage: "5Gi"
									}
								}
								storageClassName: context["storage_config.storage_class_mapping.local_disk"]
								volumesToMount: [
									{
										mountPath: "/streampark/temp"
										name:      "data-temp"
									},
								]
							}
							type: "bdos-pvc"
						},
						{
							properties: {
								name: "logs"
								path: "/var/log/" + context["namespace"] + "-" + context["name"]
								promtail: {
									cpu:    "0.1"
									memory: "128Mi"
								}
							}
							type: "bdos-logtail"
						},
						{
							properties: {
								endpoints: [
									{
										path: "/actuator/prometheus"
										port: 10000
									},
								]
							}
							type: "bdos-monitor"
						},
						{
							properties: {
								ingressClassName: parameter.ingressClassName
								stickySession:    true
								service: {
									ports: [
										{
											containerPort: 10000
											protocol:      "TCP"
										},
									]
								}
								rules: [
									{
										host: context["name"] + "-" + context["namespace"] + "." + context["ingress.root_domain"]
										paths: [
											{
												path:        "/"
												servicePort: 10000
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
						{
							"type": "bdos-grafana-dashboard"
							"properties": {
								"labels": {
									"grafana_dashboard": "1"
								}
								"dashboard_data": {
									"spring-boot-dashboard.json": "{\"annotations\":{\"list\":[{\"builtIn\":1,\"datasource\":{\"type\":\"datasource\",\"uid\":\"grafana\"},\"enable\":true,\"hide\":true,\"iconColor\":\"rgba(0,211,255,1)\",\"name\":\"Annotations&Alerts\",\"target\":{\"limit\":100,\"matchAny\":false,\"tags\":[],\"type\":\"dashboard\"},\"type\":\"dashboard\"}]},\"description\":\"DashboardforSpringBoot2Statistics(bymicrometer-prometheus).\",\"editable\":true,\"fiscalYearStartMonth\":0,\"gnetId\":6756,\"graphTooltip\":0,\"id\":57,\"links\":[],\"liveNow\":false,\"panels\":[{\"collapsed\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":0},\"id\":54,\"panels\":[],\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"refId\":\"A\"}],\"title\":\"BasicStatistics\",\"type\":\"row\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"decimals\":1,\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"s\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":3,\"w\":6,\"x\":0,\"y\":1},\"id\":52,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"showPercentChange\":false,\"textMode\":\"auto\",\"wideLayout\":true},\"pluginVersion\":\"10.3.3\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"process_uptime_seconds{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\"}\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"\",\"metric\":\"\",\"refId\":\"A\",\"step\":14400}],\"title\":\"Uptime\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"decimals\":1,\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"max\":100,\"min\":0,\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"rgba(50,172,45,0.97)\",\"value\":null},{\"color\":\"rgba(237,129,40,0.89)\",\"value\":70},{\"color\":\"rgba(245,54,54,0.9)\",\"value\":90}]},\"unit\":\"percent\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":5,\"x\":6,\"y\":1},\"id\":58,\"links\":[],\"maxDataPoints\":100,\"options\":{\"minVizHeight\":75,\"minVizWidth\":75,\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"showThresholdLabels\":false,\"showThresholdMarkers\":true,\"sizing\":\"auto\"},\"pluginVersion\":\"10.3.3\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(jvm_memory_used_bytes{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",area=\\\"heap\\\"})*100/sum(jvm_memory_max_bytes{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",area=\\\"heap\\\"})\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"\",\"refId\":\"A\",\"step\":14400}],\"title\":\"HeapUsed\",\"type\":\"gauge\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"decimals\":1,\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"},{\"options\":{\"from\":-1e+32,\"result\":{\"text\":\"N/A\"},\"to\":0},\"type\":\"range\"}],\"max\":100,\"min\":0,\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"rgba(50,172,45,0.97)\",\"value\":null},{\"color\":\"rgba(237,129,40,0.89)\",\"value\":70},{\"color\":\"rgba(245,54,54,0.9)\",\"value\":90}]},\"unit\":\"percent\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":5,\"x\":11,\"y\":1},\"id\":60,\"links\":[],\"maxDataPoints\":100,\"options\":{\"minVizHeight\":75,\"minVizWidth\":75,\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"showThresholdLabels\":false,\"showThresholdMarkers\":true,\"sizing\":\"auto\"},\"pluginVersion\":\"10.3.3\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(jvm_memory_used_bytes{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",area=\\\"nonheap\\\"})*100/sum(jvm_memory_max_bytes{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",area=\\\"nonheap\\\"})\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"\",\"refId\":\"A\",\"step\":14400}],\"title\":\"Non-HeapUsed\",\"type\":\"gauge\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":6,\"w\":8,\"x\":16,\"y\":1},\"hiddenSeries\":false,\"id\":66,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"process_files_open_files{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\"}\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"OpenFiles\",\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"process_files_max_files{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\"}\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"MaxFiles\",\"refId\":\"B\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"ProcessOpenFiles\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"locale\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"dateTimeAsIso\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":3,\"w\":6,\"x\":0,\"y\":4},\"id\":56,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"showPercentChange\":false,\"text\":{\"valueSize\":40},\"textMode\":\"auto\",\"wideLayout\":true},\"pluginVersion\":\"10.3.3\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"process_start_time_seconds{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\"}*1000\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"\",\"metric\":\"\",\"refId\":\"A\",\"step\":14400}],\"title\":\"Starttime\",\"type\":\"stat\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":0,\"y\":7},\"hiddenSeries\":false,\"id\":95,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"system_cpu_usage{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\"}\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"SystemCPUUsage\",\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"process_cpu_usage{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\"}\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"ProcessCPUUsage\",\"refId\":\"B\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"CPUUsage\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"short\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":12,\"y\":7},\"hiddenSeries\":false,\"id\":96,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"system_load_average_1m{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\"}\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"LoadAverage[1m]\",\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"system_cpu_count{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\"}\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"CPUCoreSize\",\"refId\":\"B\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"LoadAverage\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"short\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":13,\"w\":12,\"x\":0,\"y\":14},\"hiddenSeries\":false,\"id\":85,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"repeat\":\"memory_pool_heap\",\"repeatDirection\":\"h\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"jvm_memory_used_bytes{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",area=\\\"heap\\\"}\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{id}}\",\"refId\":\"C\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"memory_pool_heap\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"bytes\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"unitScale\":true},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":13,\"w\":12,\"x\":12,\"y\":14},\"hiddenSeries\":false,\"id\":88,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"10.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"repeat\":\"memory_pool_nonheap\",\"repeatDirection\":\"h\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"jvm_memory_used_bytes{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",area=\\\"heap\\\"}\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{id}}\",\"refId\":\"C\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"memory_pool_nonheap\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"bytes\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"collapsed\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":27},\"id\":48,\"panels\":[],\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"refId\":\"A\"}],\"title\":\"JVMStatistics-Memory\",\"type\":\"row\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"decimals\":0,\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":12,\"x\":0,\"y\":28},\"hiddenSeries\":false,\"id\":50,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"jvm_classes_loaded_classes{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\"}\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"ClassesLoaded\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"ClassesLoaded\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"decimals\":0,\"format\":\"locale\",\"label\":\"\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":12,\"x\":12,\"y\":28},\"hiddenSeries\":false,\"id\":80,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"irate(jvm_classes_unloaded_classes_total{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\"}[5m])\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"ClassesUnloaded\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"ClassesUnloaded\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"short\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":0,\"y\":36},\"hiddenSeries\":false,\"id\":82,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"jvm_buffer_memory_used_bytes{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",id=\\\"direct\\\"}\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"UsedBytes\",\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"jvm_buffer_total_capacity_bytes{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",id=\\\"direct\\\"}\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"CapacityBytes\",\"refId\":\"B\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"DirectBuffers\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"short\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":12,\"y\":36},\"hiddenSeries\":false,\"id\":83,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"jvm_buffer_memory_used_bytes{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",id=\\\"mapped\\\"}\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"UsedBytes\",\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"jvm_buffer_total_capacity_bytes{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",id=\\\"mapped\\\"}\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"CapacityBytes\",\"refId\":\"B\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"MappedBuffers\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"short\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":12,\"x\":0,\"y\":43},\"hiddenSeries\":false,\"id\":68,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"jvm_threads_daemon_threads{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\"}\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"Daemon\",\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"jvm_threads_live_threads{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\"}\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"Live\",\"refId\":\"B\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"jvm_threads_peak_threads{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\"}\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"Peak\",\"refId\":\"C\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Threads\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"short\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":12,\"x\":12,\"y\":43},\"hiddenSeries\":false,\"id\":78,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"irate(jvm_gc_memory_allocated_bytes_total{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\"}[5m])\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"allocated\",\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"irate(jvm_gc_memory_promoted_bytes_total{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\"}[5m])\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"promoted\",\"refId\":\"B\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"MemoryAllocate/Promote\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"bytes\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"collapsed\":true,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":51},\"id\":72,\"panels\":[{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":10,\"w\":12,\"x\":0,\"y\":52},\"hiddenSeries\":false,\"id\":74,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":false,\"hideEmpty\":true,\"hideZero\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":true,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"irate(jvm_gc_pause_seconds_count{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\"}[5m])\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"{{action}}[{{cause}}]\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"GCCount\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"locale\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":10,\"w\":12,\"x\":12,\"y\":52},\"hiddenSeries\":false,\"id\":76,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":false,\"hideEmpty\":true,\"hideZero\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":true,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"irate(jvm_gc_pause_seconds_sum{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\"}[5m])\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"{{action}}[{{cause}}]\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"GCStoptheWorldDuration\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"s\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}}],\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"refId\":\"A\"}],\"title\":\"JVMStatistics-GC\",\"type\":\"row\"},{\"collapsed\":true,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":52},\"id\":34,\"panels\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"none\"},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":4,\"x\":0,\"y\":53},\"id\":44,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"none\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"hikaricp_connections{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",pool=\\\"$hikaricp\\\"}\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"\",\"refId\":\"A\"}],\"title\":\"ConnectionsSize\",\"type\":\"stat\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":8,\"w\":20,\"x\":4,\"y\":53},\"hiddenSeries\":false,\"id\":36,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":true,\"hideEmpty\":true,\"hideZero\":false,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":true,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"hikaricp_connections_active{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",pool=\\\"$hikaricp\\\"}\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"Active\",\"refId\":\"B\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"hikaricp_connections_idle{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",pool=\\\"$hikaricp\\\"}\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"Idle\",\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"hikaricp_connections_pending{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",pool=\\\"$hikaricp\\\"}\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"Pending\",\"refId\":\"C\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Connections\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"short\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"none\"},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":4,\"x\":0,\"y\":57},\"id\":46,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"none\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"hikaricp_connections_timeout_total{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",pool=\\\"$hikaricp\\\"}\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"\",\"refId\":\"A\"}],\"title\":\"ConnectionTimeoutCount\",\"type\":\"stat\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":6,\"w\":8,\"x\":0,\"y\":61},\"hiddenSeries\":false,\"id\":38,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"hikaricp_connections_creation_seconds_sum{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",pool=\\\"$hikaricp\\\"}/hikaricp_connections_creation_seconds_count{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",pool=\\\"$hikaricp\\\"}\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"CreationTime\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"ConnectionCreationTime\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"s\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":6,\"w\":8,\"x\":8,\"y\":61},\"hiddenSeries\":false,\"id\":42,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"hikaricp_connections_usage_seconds_sum{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",pool=\\\"$hikaricp\\\"}/hikaricp_connections_usage_seconds_count{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",pool=\\\"$hikaricp\\\"}\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"UsageTime\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"ConnectionUsageTime\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"s\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":6,\"w\":8,\"x\":16,\"y\":61},\"hiddenSeries\":false,\"id\":40,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"hikaricp_connections_acquire_seconds_sum{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",pool=\\\"$hikaricp\\\"}/hikaricp_connections_acquire_seconds_count{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",pool=\\\"$hikaricp\\\"}\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"AcquireTime\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"ConnectionAcquireTime\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"s\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}}],\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"refId\":\"A\"}],\"title\":\"HikariCPStatistics\",\"type\":\"row\"},{\"collapsed\":true,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":53},\"id\":18,\"panels\":[{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":24,\"x\":0,\"y\":57},\"hiddenSeries\":false,\"id\":4,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"rightSide\":true,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"8.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"irate(http_server_requests_seconds_count{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",uri!~\\\".*actuator.*\\\"}[5m])\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"{{method}}[{{status}}]-{{uri}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"RequestCount\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"none\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":24,\"x\":0,\"y\":64},\"hiddenSeries\":false,\"id\":2,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":false,\"max\":true,\"min\":true,\"rightSide\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"8.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"irate(http_server_requests_seconds_sum{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",exception=\\\"None\\\",uri!~\\\".*actuator.*\\\"}[5m])/irate(http_server_requests_seconds_count{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",exception=\\\"None\\\",uri!~\\\".*actuator.*\\\"}[5m])\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"{{method}}[{{status}}]-{{uri}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"ResponseTime\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"s\",\"label\":\"\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}}],\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"refId\":\"A\"}],\"title\":\"HTTPStatistics\",\"type\":\"row\"},{\"collapsed\":true,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":54},\"id\":22,\"panels\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"locale\"},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":4,\"x\":0,\"y\":55},\"id\":28,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"none\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"8.3.3\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"tomcat_global_error_total{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\"}\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"\",\"refId\":\"A\"}],\"title\":\"TotalErrorCount\",\"type\":\"stat\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"decimals\":0,\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":9,\"x\":4,\"y\":55},\"hiddenSeries\":false,\"id\":24,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"8.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"tomcat_sessions_active_current_sessions{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\"}\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"activesessions\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"ActiveSessions\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"none\",\"label\":\"\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":11,\"x\":13,\"y\":55},\"hiddenSeries\":false,\"id\":26,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"8.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"irate(tomcat_global_sent_bytes_total{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\"}[5m])\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"SentBytes\",\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"irate(tomcat_global_received_bytes_total{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\"}[5m])\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"RecievedBytes\",\"refId\":\"B\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Sent&RecievedBytes\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"bytes\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"locale\"},\"overrides\":[]},\"gridPos\":{\"h\":3,\"w\":4,\"x\":0,\"y\":59},\"id\":32,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"none\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"8.3.3\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"tomcat_threads_config_max_threads{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\"}\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"\",\"refId\":\"A\"}],\"title\":\"ThreadConfigMax\",\"type\":\"stat\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":13,\"x\":0,\"y\":62},\"hiddenSeries\":false,\"id\":30,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"8.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"tomcat_threads_current_threads{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\"}\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"Currentthread\",\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"tomcat_threads_busy_threads{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\"}\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"Currentthreadbusy\",\"refId\":\"B\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Threads\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"short\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}}],\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"refId\":\"A\"}],\"title\":\"TomcatStatistics\",\"type\":\"row\"},{\"collapsed\":true,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":55},\"id\":8,\"panels\":[{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":0,\"y\":56},\"hiddenSeries\":false,\"id\":6,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":true,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"8.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"alias\":\"\",\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"irate(logback_events_total{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",level=\\\"info\\\"}[5m])\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"info\",\"rawSql\":\"SELECT\\n$__time(time_column),\\nvalue1\\nFROM\\nmetric_table\\nWHERE\\n$__timeFilter(time_column)\\n\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"INFOlogs\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"none\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":12,\"y\":56},\"hiddenSeries\":false,\"id\":10,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":true,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"8.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"alias\":\"\",\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"irate(logback_events_total{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",level=\\\"error\\\"}[5m])\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"error\",\"rawSql\":\"SELECT\\n$__time(time_column),\\nvalue1\\nFROM\\nmetric_table\\nWHERE\\n$__timeFilter(time_column)\\n\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"ERRORlogs\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"none\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":8,\"x\":0,\"y\":63},\"hiddenSeries\":false,\"id\":14,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":true,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"8.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"alias\":\"\",\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"irate(logback_events_total{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",level=\\\"warn\\\"}[5m])\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"warn\",\"rawSql\":\"SELECT\\n$__time(time_column),\\nvalue1\\nFROM\\nmetric_table\\nWHERE\\n$__timeFilter(time_column)\\n\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"WARNlogs\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"none\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":8,\"x\":8,\"y\":63},\"hiddenSeries\":false,\"id\":16,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":true,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"8.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"alias\":\"\",\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"irate(logback_events_total{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",level=\\\"debug\\\"}[5m])\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"debug\",\"rawSql\":\"SELECT\\n$__time(time_column),\\nvalue1\\nFROM\\nmetric_table\\nWHERE\\n$__timeFilter(time_column)\\n\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"DEBUGlogs\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"none\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":8,\"x\":16,\"y\":63},\"hiddenSeries\":false,\"id\":20,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":true,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"8.3.3\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"alias\":\"\",\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"irate(logback_events_total{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\",level=\\\"trace\\\"}[5m])\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"trace\",\"rawSql\":\"SELECT\\n$__time(time_column),\\nvalue1\\nFROM\\nmetric_table\\nWHERE\\n$__timeFilter(time_column)\\n\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"TRACElogs\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"format\":\"none\",\"logBase\":1,\"show\":true},{\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}}],\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"refId\":\"A\"}],\"title\":\"LogbackStatistics\",\"type\":\"row\"}],\"refresh\":\"1m\",\"schemaVersion\":39,\"tags\":[],\"templating\":{\"list\":[{\"current\":{\"selected\":false,\"text\":\"Prometheus\",\"value\":\"prometheus\"},\"hide\":0,\"includeAll\":false,\"multi\":false,\"name\":\"datasource\",\"options\":[],\"query\":\"prometheus\",\"refresh\":1,\"regex\":\"\",\"skipUrlSync\":false,\"type\":\"datasource\"},{\"current\":{\"selected\":false,\"text\":\"kdp-data\",\"value\":\"kdp-data\"},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"definition\":\"label_values(jvm_classes_loaded_classes,namespace)\",\"hide\":0,\"includeAll\":false,\"label\":\"namespace\",\"multi\":false,\"name\":\"namespace\",\"options\":[],\"query\":{\"query\":\"label_values(jvm_classes_loaded_classes,namespace)\",\"refId\":\"StandardVariableQuery\"},\"refresh\":1,\"regex\":\"\",\"skipUrlSync\":false,\"sort\":0,\"type\":\"query\"},{\"current\":{\"selected\":false,\"text\":\"streampark-svc\",\"value\":\"streampark-svc\"},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"definition\":\"label_values(jvm_classes_loaded_classes{namespace=\\\"$namespace\\\"},job)\",\"hide\":0,\"includeAll\":false,\"label\":\"job\",\"multi\":false,\"name\":\"job\",\"options\":[],\"query\":{\"query\":\"label_values(jvm_classes_loaded_classes{namespace=\\\"$namespace\\\"},job)\",\"refId\":\"StandardVariableQuery\"},\"refresh\":1,\"regex\":\"\",\"skipUrlSync\":false,\"sort\":0,\"type\":\"query\"},{\"current\":{\"selected\":false,\"text\":\"10.233.110.100:10000\",\"value\":\"10.233.110.100:10000\"},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"definition\":\"label_values(jvm_classes_loaded_classes{namespace=\\\"$namespace\\\",job=\\\"$job\\\"},instance)\",\"hide\":0,\"includeAll\":false,\"label\":\"instance\",\"multi\":false,\"name\":\"instance\",\"options\":[],\"query\":{\"query\":\"label_values(jvm_classes_loaded_classes{namespace=\\\"$namespace\\\",job=\\\"$job\\\"},instance)\",\"refId\":\"StandardVariableQuery\"},\"refresh\":1,\"regex\":\"\",\"skipUrlSync\":false,\"sort\":0,\"type\":\"query\"},{\"current\":{\"selected\":false,\"text\":\"HikariPool-1\",\"value\":\"HikariPool-1\"},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"definition\":\"label_values(hikaricp_connections{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\"},pool)\",\"hide\":0,\"includeAll\":false,\"label\":\"hikaricp\",\"multi\":false,\"name\":\"hikaricp\",\"options\":[],\"query\":{\"query\":\"label_values(hikaricp_connections{namespace=\\\"$namespace\\\",job=\\\"$job\\\",instance=\\\"$instance\\\"},pool)\",\"refId\":\"StandardVariableQuery\"},\"refresh\":1,\"regex\":\"\",\"skipUrlSync\":false,\"sort\":0,\"type\":\"query\"}]},\"time\":{\"from\":\"now-30m\",\"to\":\"now\"},\"timepicker\":{\"refresh_intervals\":[\"5s\",\"10s\",\"30s\",\"1m\",\"5m\",\"15m\",\"30m\",\"1h\",\"2h\",\"1d\"],\"time_options\":[\"5m\",\"15m\",\"1h\",\"6h\",\"12h\",\"24h\",\"2d\",\"7d\",\"30d\"]},\"timezone\":\"\",\"title\":\"SpringBoot2.2.12\",\"uid\":\"springboot\",\"version\":1,\"weekStart\":\"\"}"
								}
							}
						},
					]

				},
			]
			policies: [
				{
					name: "garbage-collect"
					properties: {
						rules: [
							{
								selector: {
									traitTypes: [
										"bdos-pvc",
									]
								}
								strategy: "never"
							},
						]
					}
					type: "garbage-collect"
				},
				{
					name: "take-over"
					properties: {
						rules: [
							{
								selector: {
									traitTypes: [
										"bdos-pvc",
									]
								}
							},
						]
					}
					type: "take-over"
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
				// +err:options={"pattern":"请输入正确的CPU格式，如0.25，250m"}
				// +ui:description=CPU
				cpu: *"0.25" | string

				// +pattern=^[1-9]\d*(Mi|Gi)$
				// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
				// +ui:description=内存
				memory: *"512Mi" | string
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
				memory: *"512Mi" | string
			}
		}

		// +ui:description=配置访问 Ingress 地址的 IngressClass, 如果您不清楚IngressClass，请勿随意更改
		// +ui:order=4
		ingressClassName: *"kong" | string

		// +ui:description=镜像版本
		// +ui:options={"disabled": true}
		// +ui:order=5
		image: *"streampark:v1.0.0-2.1.2" | string

		// +ui:hidden=true
		imagePullSecrets?: [...string]
	}

}
