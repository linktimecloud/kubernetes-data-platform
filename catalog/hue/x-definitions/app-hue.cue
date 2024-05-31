import "strings"

hue: {
	annotations: {}
	labels: {}
	attributes: {
		dynamicParameterMeta: [
			{
				name:        "hue.mysql.mysqlSetting"
				type:        "ContextSetting"
				refType:     "mysql"
				refKey:      ""
				description: "mysql setting name"
				required:    true
			},
			{
				name:        "hue.mysql.mysqlSecret"
				type:        "ContextSecret"
				refType:     "mysql"
				refKey:      ""
				description: "mysql secret name"
				required:    true
			},
			{
				name:        "hue.httpfsContext"
				type:        "ContextSetting"
				refType:     "httpfs"
				refKey:      ""
				description: "httpfs context name"
				required:    true
			},
			{
				name:        "hue.zookeeperContext"
				type:        "ContextSetting"
				refType:     "zookeeper"
				refKey:      ""
				description: "zookeeper context name"
				required:    true
			},
			{
				name:        "hue.hs2Context"
				type:        "ContextSetting"
				refType:     "hive-server2"
				refKey:      ""
				description: "hive-server2 context name"
				required:    true
			},

		]
		apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "Application"
				type:       "hue"
			}
		}

	}
	description: "hue"
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
							name: context.name
							if parameter.namespace != _|_ {
								namespace: parameter.namespace
							}
						}
						spec: {
							if parameter["replicas"] != _|_ {
								replicas: parameter.replicas
							}
							selector: matchLabels: {
								app:                     context.name
								"app.oam.dev/component": context.name
							}
							template: {
								metadata: {
									labels: {
										app:                     context.name
										"app.oam.dev/component": context.name
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
												name:  "ADMIN_USER"
												value: "root"
											},
											//mysql config
											{
												name:  "INIT_DB"
												value: "true"
											},
											{
												name:  "MYSQL_DATABASE"
												value: "\(strings.Replace(context.namespace+"_hue", "-", "_", -1))"
											},
											{
												name: "MYSQL_HOST"
												valueFrom: {
													configMapKeyRef: {
														name: "\(parameter.hue.mysql.mysqlSetting)"
														key:  "MYSQL_HOST"
													}
												}
											},
											{
												name: "MYSQL_PORT"
												valueFrom: {
													configMapKeyRef: {
														name: "\(parameter.hue.mysql.mysqlSetting)"
														key:  "MYSQL_PORT"
													}
												}
											},
											{
												name: "MYSQL_PASSWD"
												valueFrom: {
													secretKeyRef: {
														name: "\(parameter.hue.mysql.mysqlSecret)"
														key:  "MYSQL_PASSWORD"
													}
												}
											},
											{
												name: "MYSQL_UID"
												valueFrom: {
													secretKeyRef: {
														name: "\(parameter.hue.mysql.mysqlSecret)"
														key:  "MYSQL_USER"
													}
												}
											},
											// httpfs config
											{
												name: "HTTPFS_GATEWAY_HOSTNAME"
												valueFrom: {
													configMapKeyRef: {
														name: "\(parameter.hue.httpfsContext)"
														key:  "hostname"
													}
												}
											},
											{
												name: "HTTPFS_GATEWAY_PORT"
												valueFrom: {
													configMapKeyRef: {
														name: "\(parameter.hue.httpfsContext)"
														key:  "port"
													}
												}
											},
											{
												name: "ZOOKEEPER_VIP"
												valueFrom: {
													configMapKeyRef: {
														name: "\(parameter.hue.zookeeperContext)"
														key:  "host"
													}
												}
											},
											// hs2 zk node
											{
												name: "ZOOKEEPER_PATH"
												valueFrom: {
													configMapKeyRef: {
														name: "\(parameter.hue.hs2Context)"
														key:  "zookeeper_node"
													}
												}
											},
											{
												name:  "TIMEZONE"
												value: "Asia/Shanghai"
											},
											{
												name:  "DJANGO_DEBUG_ENABLE"
												value: "\(parameter.hue.djangoDebugEnable)"
											},
										]
										image: context["docker_registry"] + "/" + parameter.image
										if parameter.command != _|_ {
											command: parameter.command
										}
										if parameter["args"] != _|_ {
											args: parameter.args
										}
										startupProbe: {
											httpGet: {
												path: "/desktop/debug/is_alive"
												port: 8887
											}
											failureThreshold: 60
											periodSeconds:    10
										}
										livenessProbe: {
											httpGet: {
												path: "/desktop/debug/is_alive"
												port: 8887
											}
											periodSeconds:    10
											timeoutSeconds:   10
											successThreshold: 1
											failureThreshold: 6
										}
										readinessProbe: {
											exec: {
												command: [
													"bash",
													"./readiness.sh",
												]
											}
											periodSeconds:    10
											timeoutSeconds:   30
											successThreshold: 1
											failureThreshold: 6
										}
										volumeMounts: [{
											mountPath: "/usr/share/hue/logs"
											name:      "logs"
										}]
									}]
									restartPolicy: "Always"
									if parameter["imagePullSecrets"] != _|_ {
										imagePullSecrets: [ for v in parameter.imagePullSecrets {
											name: v
										},
										]
									}
									serviceAccountName: context.name
								}
							}
						}
					}
					traits: [
						{
							properties: {
								name: context["name"]
							}
							type: "bdos-service-account"
						},
						{
							properties: {
								name: "logs"
								path: "/var/log/" + context["namespace"] + "-" + context["name"]
								promtail: {
									cpu:    "0.1"
									memory: "64Mi"
								}
							}
							type: "bdos-logtail"
						},

						{
							properties: {
								stickySession:    true
								service: {
									ports: [
										{
											containerPort: 8887
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
												servicePort: 8887
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
							properties: {
								endpoints: [
									{
										port: 8887
									},
								]
							}
							type: "bdos-monitor"
						},
						{
							properties: {
								groups: [
									{
										name: context["namespace"] + "-hue.rules"
										rules: [
											{
												alert: context["namespace"] + "-HueHttpLatency"
												annotations: {
													description: "Hue http latency is too high. Namespace: {{ $labels.namespace }}, pod: {{ $labels.pod }}"
													summary:     "Hue http latency is too high"
												}
												duration: "10m"
												expr:     "histogram_quantile(0.95, rate(django_http_requests_latency_including_middlewares_seconds_bucket{}[5m])) \u003e 2"
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

				},

				{
					name: "hue-grafana-dashboard"
					properties: {
						apiVersion: "v1"
						data: {
							"hue-dashboard.json": "{\"annotations\":{\"list\":[{\"builtIn\":1,\"datasource\":{\"type\":\"datasource\",\"uid\":\"grafana\"},\"enable\":true,\"hide\":true,\"iconColor\":\"rgba(0, 211, 255, 1)\",\"name\":\"Annotations \u0026 Alerts\",\"target\":{\"limit\":100,\"matchAny\":false,\"tags\":[],\"type\":\"dashboard\"},\"type\":\"dashboard\"}]},\"description\":\"\",\"editable\":true,\"fiscalYearStartMonth\":0,\"gnetId\":9528,\"graphTooltip\":0,\"id\":74,\"links\":[],\"liveNow\":false,\"panels\":[{\"collapsed\":false,\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":0},\"id\":34,\"panels\":[],\"title\":\"Basic\",\"type\":\"row\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"percentunit\"},\"overrides\":[]},\"gridPos\":{\"h\":7,\"w\":7,\"x\":0,\"y\":1},\"id\":21,\"options\":{\"legend\":{\"calcs\":[\"max\"],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"rate(process_cpu_seconds_total{namespace=\\\"$namespace\\\",service=\\\"$service\\\",pod=\\\"$pod\\\"}[1m])\",\"instant\":false,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"CPU usage\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"bytes\"},\"overrides\":[]},\"gridPos\":{\"h\":7,\"w\":7,\"x\":7,\"y\":1},\"id\":25,\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"process_virtual_memory_bytes{namespace=\\\"$namespace\\\",service=\\\"$service\\\",pod=\\\"$pod\\\"}\",\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"Memory usage（VSZ）\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"bytes\"},\"overrides\":[]},\"gridPos\":{\"h\":7,\"w\":7,\"x\":14,\"y\":1},\"id\":24,\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"process_resident_memory_bytes{namespace=\\\"$namespace\\\",service=\\\"$service\\\",pod=\\\"$pod\\\"}\",\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"Memory usage（RSS）\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Objects collected during gc\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":1,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"ops\"},\"overrides\":[]},\"gridPos\":{\"h\":7,\"w\":7,\"x\":0,\"y\":8},\"id\":30,\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"rate(python_gc_objects_collected_total{namespace=\\\"$namespace\\\",service=\\\"$service\\\",pod=\\\"$pod\\\"}[1m])\",\"legendFormat\":\"generation {{generation}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"Collected Objects Rate\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Number of times this generation was collected\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":1,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"decimals\":2,\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"ops\"},\"overrides\":[]},\"gridPos\":{\"h\":7,\"w\":7,\"x\":7,\"y\":8},\"id\":36,\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"rate(python_gc_collections_total{namespace=\\\"$namespace\\\",service=\\\"$service\\\",pod=\\\"$pod\\\"}[$__rate_interval])\",\"legendFormat\":\"generation {{generation}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"Generation type GC(Rate)\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Uncollectable object found during GC\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":1,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"ops\"},\"overrides\":[]},\"gridPos\":{\"h\":7,\"w\":7,\"x\":14,\"y\":8},\"id\":35,\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"rate(python_gc_objects_uncollectable_total{namespace=\\\"$namespace\\\",service=\\\"$service\\\",pod=\\\"$pod\\\"}[$__rate_interval])\",\"legendFormat\":\"generation {{generation}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"Uncollectable objects(GC Rate)\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Number of open file descriptors\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"none\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":7,\"x\":0,\"y\":15},\"id\":23,\"options\":{\"legend\":{\"calcs\":[\"max\"],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"process_open_fds{namespace=\\\"$namespace\\\",service=\\\"$service\\\",pod=\\\"$pod\\\"}\",\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"Open File Descriptors Count\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"dateTimeAsIso\"},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":6,\"x\":7,\"y\":15},\"id\":29,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"text\":{\"valueSize\":40},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"process_start_time_seconds{namespace=\\\"$namespace\\\",service=\\\"$service\\\",pod=\\\"$pod\\\"}*1000\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"\",\"metric\":\"\",\"refId\":\"A\",\"step\":14400}],\"title\":\"Start time\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"dateTimeFromNow\"},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":6,\"x\":7,\"y\":19},\"id\":40,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"text\":{\"valueSize\":40},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"process_start_time_seconds{namespace=\\\"$namespace\\\",service=\\\"$service\\\",pod=\\\"$pod\\\"}*1000\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"\",\"metric\":\"\",\"refId\":\"A\",\"step\":14400}],\"title\":\"Uptime\",\"type\":\"stat\"},{\"collapsed\":false,\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":23},\"id\":32,\"panels\":[],\"title\":\"Hue\",\"type\":\"row\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"none\"},\"overrides\":[]},\"gridPos\":{\"h\":2,\"w\":4,\"x\":0,\"y\":24},\"id\":15,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"none\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"mean\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"uid\":\"$datasource\"},\"expr\":\"sum(irate(django_http_responses_total_by_status_total{status=~\\\"2.+\\\",namespace=\\\"$namespace\\\", service=\\\"$service\\\", pod=\\\"$pod\\\"}[1m]))\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"\",\"refId\":\"A\"}],\"title\":\"2XX Responses (irate)\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"none\"},\"overrides\":[]},\"gridPos\":{\"h\":2,\"w\":4,\"x\":4,\"y\":24},\"id\":16,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"none\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"mean\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(irate(django_http_responses_total_by_status_total{status=~\\\"5.+\\\",namespace=\\\"$namespace\\\", service=\\\"$service\\\", pod=\\\"$pod\\\"}[1m]))\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"\",\"refId\":\"A\"}],\"title\":\"4XX Responses (irate)\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"none\"},\"overrides\":[]},\"gridPos\":{\"h\":2,\"w\":4,\"x\":8,\"y\":24},\"id\":17,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"none\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"mean\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"uid\":\"$datasource\"},\"expr\":\"sum(irate(django_http_responses_total_by_status_total{status=~\\\"5.+\\\",namespace=\\\"$namespace\\\", service=\\\"$service\\\", pod=\\\"$pod\\\"}[1m]))\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"\",\"refId\":\"A\"}],\"title\":\"5XX Responses (irate)\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"dtdurations\"},\"overrides\":[]},\"gridPos\":{\"h\":11,\"w\":11,\"x\":12,\"y\":24},\"id\":4,\"links\":[],\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"histogram_quantile(0.50, rate(django_http_requests_latency_including_middlewares_seconds_bucket{namespace=\\\"$namespace\\\", service=\\\"$service\\\", pod=\\\"$pod\\\"}[$__rate_interval]))\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"quantile=50\",\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"histogram_quantile(0.95, rate(django_http_requests_latency_including_middlewares_seconds_bucket{namespace=\\\"$namespace\\\", service=\\\"$service\\\", pod=\\\"$pod\\\"}[$__rate_interval]))\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"quantile=95\",\"refId\":\"B\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"histogram_quantile(0.99, rate(django_http_requests_latency_including_middlewares_seconds_bucket{namespace=\\\"$namespace\\\", service=\\\"$service\\\", pod=\\\"$pod\\\"}[$__rate_interval]))\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"quantile=99\",\"refId\":\"C\"}],\"title\":\"Request Latency\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"decimals\":2,\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"reqps\"},\"overrides\":[]},\"gridPos\":{\"h\":9,\"w\":12,\"x\":0,\"y\":26},\"id\":11,\"links\":[],\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(irate(django_http_responses_total_by_status_total{namespace=\\\"$namespace\\\", service=\\\"$service\\\", pod=\\\"$pod\\\"}[$__rate_interval])) by(status)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{status}}\",\"refId\":\"A\"}],\"title\":\"HTTP response (irate)\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"description\":\"django_db_execute_total\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"decimals\":2,\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"ops\"},\"overrides\":[{\"matcher\":{\"id\":\"byName\",\"options\":\"mysql\"},\"properties\":[{\"id\":\"color\",\"value\":{\"fixedColor\":\"#584477\",\"mode\":\"fixed\"}}]},{\"matcher\":{\"id\":\"byName\",\"options\":\"postgresql\"},\"properties\":[{\"id\":\"color\",\"value\":{\"fixedColor\":\"#0064a5\",\"mode\":\"fixed\"}}]}]},\"gridPos\":{\"h\":10,\"w\":12,\"x\":0,\"y\":35},\"id\":9,\"links\":[],\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(irate(django_db_execute_total{namespace=\\\"$namespace\\\", service=\\\"$service\\\", pod=\\\"$pod\\\"}[1m])) by (vendor)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{vendor}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"hue backend database execute(irate)\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"binBps\"},\"overrides\":[]},\"gridPos\":{\"h\":10,\"w\":11,\"x\":12,\"y\":35},\"id\":41,\"links\":[],\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"histogram_quantile(0.50, rate(django_http_responses_body_total_bytes_bucket{namespace=\\\"$namespace\\\", service=\\\"$service\\\", pod=\\\"$pod\\\"}[5m]))\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"quantile=50\",\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"histogram_quantile(0.95, rate(django_http_responses_body_total_bytes_bucket{namespace=\\\"$namespace\\\", service=\\\"$service\\\", pod=\\\"$pod\\\"}[5m]))\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"quantile=95\",\"refId\":\"B\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"histogram_quantile(0.99, rate(django_http_responses_body_total_bytes_bucket{namespace=\\\"$namespace\\\", service=\\\"$service\\\", pod=\\\"$pod\\\"}[5m]))\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"quantile=99\",\"refId\":\"C\"}],\"title\":\"HTTP request body size\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Hue active users per instance\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"count\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"links\":[],\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":9,\"w\":12,\"x\":0,\"y\":45},\"id\":2,\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"hue_local_active_users{namespace=\\\"$namespace\\\", service=\\\"$service\\\", pod=\\\"$pod\\\"}\",\"interval\":\"\",\"legendFormat\":\"hue_local_active_users\",\"range\":true,\"refId\":\"A\"}],\"title\":\"Hue Local Active Users\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"hue_queries_numbers\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"links\":[],\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":9,\"w\":11,\"x\":12,\"y\":45},\"id\":19,\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"hue_queries_numbers{namespace=\\\"$namespace\\\", service=\\\"$service\\\", pod=\\\"$pod\\\"}\",\"interval\":\"\",\"legendFormat\":\"hue_queries_numbers\",\"refId\":\"A\"}],\"title\":\"hue query job count\",\"type\":\"timeseries\"}],\"refresh\":\"1m\",\"schemaVersion\":36,\"style\":\"dark\",\"tags\":[\"python\",\"django\"],\"templating\":{\"list\":[{\"current\":{\"selected\":false,\"text\":\"Prometheus\",\"value\":\"Prometheus\"},\"hide\":0,\"includeAll\":false,\"multi\":false,\"name\":\"datasource\",\"options\":[],\"query\":\"prometheus\",\"refresh\":1,\"regex\":\"\",\"skipUrlSync\":false,\"type\":\"datasource\"},{\"allValue\":\".*\",\"current\":{\"selected\":false,\"text\":\"admin\",\"value\":\"admin\"},\"datasource\":{\"uid\":\"$datasource\"},\"definition\":\"\",\"hide\":0,\"includeAll\":false,\"label\":\"\",\"multi\":false,\"name\":\"namespace\",\"options\":[],\"query\":{\"query\":\"label_values(django_db_new_connections_total, namespace)\",\"refId\":\"Prometheus-namespace-Variable-Query\"},\"refresh\":1,\"regex\":\"\",\"skipUrlSync\":false,\"sort\":1,\"tagValuesQuery\":\"\",\"tagsQuery\":\"\",\"type\":\"query\",\"useTags\":false},{\"current\":{\"selected\":false,\"text\":\"hue-service-svc\",\"value\":\"hue-service-svc\"},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"definition\":\"label_values(django_db_new_connections_total{namespace=\\\"$namespace\\\"}, service)\",\"hide\":0,\"includeAll\":false,\"label\":\"service\",\"multi\":false,\"name\":\"service\",\"options\":[],\"query\":{\"query\":\"label_values(django_db_new_connections_total{namespace=\\\"$namespace\\\"}, service)\",\"refId\":\"StandardVariableQuery\"},\"refresh\":1,\"regex\":\"\",\"skipUrlSync\":false,\"sort\":0,\"type\":\"query\"},{\"current\":{\"selected\":false,\"text\":\"hue-service-99764f56c-mqx7b\",\"value\":\"hue-service-99764f56c-mqx7b\"},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"definition\":\"label_values(django_db_new_connections_total{namespace=\\\"$namespace\\\",service=\\\"$service\\\"}, pod)\",\"hide\":0,\"includeAll\":false,\"label\":\"pod\",\"multi\":false,\"name\":\"pod\",\"options\":[],\"query\":{\"query\":\"label_values(django_db_new_connections_total{namespace=\\\"$namespace\\\",service=\\\"$service\\\"}, pod)\",\"refId\":\"StandardVariableQuery\"},\"refresh\":1,\"regex\":\"\",\"skipUrlSync\":false,\"sort\":1,\"type\":\"query\"}]},\"time\":{\"from\":\"now-1h\",\"to\":\"now\"},\"timepicker\":{\"refresh_intervals\":[\"5s\",\"10s\",\"30s\",\"1m\",\"5m\",\"15m\",\"30m\",\"1h\",\"2h\",\"1d\"],\"time_options\":[\"5m\",\"15m\",\"1h\",\"6h\",\"12h\",\"24h\",\"2d\",\"7d\",\"30d\"]},\"timezone\":\"\",\"title\":\"Hue Django\",\"uid\":\"hue\",\"version\":2,\"weekStart\":\"\"}"
						}
						kind: "ConfigMap"
						metadata: {
							labels: {
								app:               "grafana"
								grafana_dashboard: "1"
							}
							name:      "hue-grafana-dashboard"
							namespace: context["namespace"]
						}
					}
					type: "raw"
				},
			]

		}
	}

	parameter: {
		// +ui:title=组件依赖
		// +ui:order=1
		hue: {
			// +ui:description=Hadoop httpfs 依赖配置
			// +ui:order=1
			// +err:options={"required":"请先安装Hadoop httpfs-gateway组件"}
			httpfsContext: string

			// +ui:description=Hive server2 依赖配置
			// +ui:order=2
			// +err:options={"required":"请先安装Hive server2组件"}
			hs2Context: string

			// +ui:description=Zookeeper 依赖配置
			// +ui:order=3
			// +err:options={"required":"请先安装Zookeeper组件"}
			zookeeperContext: string

			// +ui:hidden=true
			djangoDebugEnable: *false | bool

			// +ui:description=Hue 元数据库配置
			// +ui:order=4
			mysql: {
				// +ui:description=数据库连接信息
				// +err:options={"required":"请先安装MySQL组件"}
				mysqlSetting: string

				// +ui:description=数据库认证信息
				// +err:options={"required":"请先安装MySQL组件"}
				mysqlSecret: string
			}
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
				// ^(\d+(\.\d{0,3})?|\d+m?)$
				// +err:options={"pattern":"请输入正确的CPU格式，如0.25，250m"}
				// +ui:description=CPU
				cpu: *"0.5" | string

				// +pattern=^[1-9]\d*(Mi|Gi)$
				// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
				// +ui:description=内存
				memory: *"1024Mi" | string
			}
		}

		// +ui:description=容器镜像
		// +ui:options={"disabled": true}
		// +ui:order=5
		image: *"hue:v1.0.0-4.10.0" | string
	}

}
