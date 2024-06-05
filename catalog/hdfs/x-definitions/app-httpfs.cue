"httpfs": {
	annotations: {}
	labels: {}
	attributes: {
		"dynamicParameterMeta": [
			{
				"name":        "dependencies.httpfs.hdfsContext"
				"type":        "ContextSetting"
				"refType":     "hdfs"
				"refKey":      ""
				"description": "hdfs context"
				"required":    true
			},
		]
		apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "Application"
				type:       "httpfs"
			}
		}
	}
	description: "httpfs gateway"
	type:        "xdefinition"
}

template: {
	output: {
		"apiVersion": "core.oam.dev/v1beta1"
		"kind":       "Application"
		"metadata": {
			"name":      context["name"]
			"namespace": context["namespace"]
			"labels": {
				"app":                context["name"]
				"app.core.bdos/type": "system"
			}
			"annotations": {
				"app.core.bdos/catalog":      "hdfs"
				"reloader.stakater.com/auto": "true"
			}
		}
		"spec": {
			"components": [
				{
					"name": context["name"]
					"type": "k8s-objects"
					"properties": objects: [{
						apiVersion: "apps/v1"
						kind:       "Deployment"
						metadata: {
							annotations: {
								"app.core.bdos/catalog": "hdfs"
							}
							labels: {
								app:                  context.name
								"app.core.bdos/type": "system"
							}
							name:      context.name
							namespace: context.namespace
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
										_customEnv: [...]
										if parameter.env != _|_ {
											_customEnv: parameter.env
										}

										env: [
											{
												name:  "HTTPFS_GATEWAY_HOSTNAME"
												value: "httpfs-gateway-svc.\(context.namespace).svc.cluster.local"
											},
											{
												name:  "HTTPFS_GATEWAY_PORT"
												value: "14000"
											},
											{
												name:  "ADMIN_USER"
												value: "root"
											},
										]
										image:           context["docker_registry"] + "/" + parameter.image
										imagePullPolicy: "IfNotPresent"
										if parameter.command != _|_ {
											command: parameter.command
										}
										if parameter["args"] != _|_ {
											args: parameter.args
										}
										"livenessProbe": {
											"exec": {
												"command": [
													"bash",
													"/root/healthcheck.sh",
												]
											}
											"initialDelaySeconds": 30
											"timeoutSeconds":      3
											"periodSeconds":       10
											"successThreshold":    1
											"failureThreshold":    3
										}
										"readinessProbe": {
											"exec": {
												"command": [
													"bash",
													"/root/healthcheck.sh",
												]
											}
											"initialDelaySeconds": 30
											"timeoutSeconds":      3
											"periodSeconds":       10
											"successThreshold":    1
											"failureThreshold":    3
										}
										if parameter.resources != _|_ {
											resources: parameter.resources
										}
										volumeMounts: [{
											mountPath: "/usr/local/hadoop/logs"
											name:      "logs"
										},
											{
												name:      "hdfs-conf"
												readOnly:  true
												mountPath: "/tmp/hdfs-config"
											},
										]
									}]
									restartPolicy: "Always"
									imagePullSecrets: [ {
										name: context["K8S_IMAGE_PULL_SECRETS_NAME"]
									},
									]
									volumes: [{
										emptyDir: {}
										name: "logs"
									},
										{
											name: "hdfs-conf"
											configMap: {
												defaultMode: 420
												name:        parameter.dependencies.httpfs.hdfsContext
											}
										},
									]
								}
							}
						}
					}]
					"traits": [
						{
							"type": "bdos-service-account"
							"properties": {
								"name": context["name"]
							}
						},
						{
							"type": "bdos-logtail"
							"properties": {
								"name": "logs"
								"path": "/var/log/" + context["namespace"] + "-" + context["name"]
								"promtail": {
									"cpu":    "0.1"
									"memory": "128Mi"
								}
							}
						},
						{
							"type": "bdos-expose"
							"properties": {
								"ports": [
									{
										"containerPort": 14000
										"protocol":      "TCP"
									},
									{
										"containerPort": 14002
										"protocol":      "TCP"
									},
								]
							}
						},
						{
							"type": "bdos-monitor"
							"properties": {
								"endpoints": [
									{
										"port": 14002
										"path": "/metrics"
									},
								]
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
										"name": context["namespace"] + "-" + context["name"] + ".rules"
										"rules": [
											{
												"alert":    context["namespace"] + "-catalina-servlet-error"
												"expr":     "rate(Catalina_Servlet_errorCount{}[5m]) > 0.1"
												"duration": "5m"
												"labels": {
													"severity": "warning"
												}
												"annotations": {
													"summary":     "Service {{ $labels.namespace }}/{{$labels.service}} catalina servlet error"
													"description": "Service {{ $labels.namespace }}/{{$labels.service}} catalina servlet error count is rising.\n VALUE {{ $value }}\n LABELS {{ $labels }}"
												}
											},
											{
												"alert":    context["namespace"] + "-HttpfsGatewayLatency"
												"expr":     "rate(Catalina_Servlet_processingTime[5m]) > 4000"
												"duration": "5m"
												"labels": {
													"severity": "warning"
												}
												"annotations": {
													"summary":     "Httpfs gateway latency is too high"
													"description": "Httpfs gateway latency is too high. Namespace: {{ $labels.namespace }}, pod: {{ $labels.pod }}"
												}
											},
										]
									},
								]
							}
						},
					]
				},
				{
					"name": "httpfs-gateway-dashboard"
					"type": "k8s-objects"
					"properties": objects: [{
						"apiVersion": "v1"
						"kind":       "ConfigMap"
						"metadata": {
							"namespace": context["namespace"]
							"name":      "httpfs-gateway-dashboard"
							"labels": {
								"app":               "grafana"
								"grafana_dashboard": "1"
							}
						}
						"data": {
							"httpfs-gateway-dashboard.json": "{\"annotations\":{\"list\":[{\"builtIn\":1,\"datasource\":{\"type\":\"datasource\",\"uid\":\"grafana\"},\"enable\":true,\"hide\":true,\"iconColor\":\"rgba(0, 211, 255, 1)\",\"name\":\"Annotations & Alerts\",\"target\":{\"limit\":100,\"matchAny\":false,\"tags\":[],\"type\":\"dashboard\"},\"type\":\"dashboard\"}]},\"description\":\"jmx exporter monitor\",\"editable\":true,\"fiscalYearStartMonth\":0,\"gnetId\":11122,\"graphTooltip\":0,\"id\":135,\"links\":[],\"liveNow\":false,\"panels\":[{\"collapsed\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":0},\"id\":18,\"panels\":[],\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"refId\":\"A\"}],\"title\":\"System Info\",\"type\":\"row\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"java_lang_OperatingSystem_ProcessCpuLoad\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":1,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"percentunit\"},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":6,\"x\":0,\"y\":1},\"id\":10,\"links\":[],\"maxDataPoints\":100,\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"java_lang_OperatingSystem_ProcessCpuLoad{job=\\\"httpfs-gateway-svc\\\", pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"CPU Load\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"java_lang_Threading_ThreadCount\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":6,\"x\":6,\"y\":1},\"id\":40,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\",\"max\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"java_lang_Threading_ThreadCount{job=\\\"httpfs-gateway-svc\\\", pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}\",\"format\":\"time_series\",\"instant\":false,\"intervalFactor\":1,\"legendFormat\":\"total\",\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"java_lang_Threading_DaemonThreadCount{job=\\\"httpfs-gateway-svc\\\", pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"daemon\",\"refId\":\"B\"}],\"title\":\"Threads Count\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":6,\"x\":12,\"y\":1},\"id\":44,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\",\"max\",\"min\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"java_lang_ClassLoading_LoadedClassCount{job=\\\"httpfs-gateway-svc\\\", pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"loaded\",\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"java_lang_ClassLoading_UnloadedClassCount{job=\\\"httpfs-gateway-svc\\\", pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"unloaded\",\"refId\":\"B\"}],\"title\":\"Class Loaded / Unloaded\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"java_lang_OperatingSystem_OpenFileDescriptorCount\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":0,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":1,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"auto\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]}},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":6,\"x\":18,\"y\":1},\"id\":16,\"links\":[],\"maxDataPoints\":100,\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"java_lang_OperatingSystem_OpenFileDescriptorCount{job=\\\"httpfs-gateway-svc\\\", pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}\",\"format\":\"time_series\",\"instant\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"title\":\"Open file descriptors\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"up\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"0\":{\"text\":\"DOWN\"},\"1\":{\"text\":\"UP\"}},\"type\":\"value\"},{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"DOWN\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"#d44a3a\",\"value\":null},{\"color\":\"rgba(237, 129, 40, 0.89)\",\"value\":0},{\"color\":\"#299c46\",\"value\":1}]},\"unit\":\"none\"},\"overrides\":[]},\"gridPos\":{\"h\":3,\"w\":6,\"x\":0,\"y\":7},\"id\":2,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":false,\"expr\":\"up{pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}\",\"format\":\"time_series\",\"instant\":true,\"interval\":\"\",\"intervalFactor\":4,\"legendFormat\":\"\",\"refId\":\"A\"}],\"title\":\"Status\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"java_lang_Runtime_Uptime\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"decimals\":0,\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"s\"},\"overrides\":[]},\"gridPos\":{\"h\":3,\"w\":6,\"x\":6,\"y\":7},\"id\":4,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"none\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"java_lang_Runtime_Uptime{job=\\\"httpfs-gateway-svc\\\", pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"} / 1000\",\"format\":\"time_series\",\"instant\":true,\"intervalFactor\":1,\"refId\":\"A\"}],\"title\":\"Uptime\",\"type\":\"stat\"},{\"collapsed\":true,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":10},\"id\":26,\"panels\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"axisWidth\":80,\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"decimals\":2,\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"cps\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":12,\"x\":0,\"y\":11},\"id\":22,\"links\":[],\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"rate(java_lang_GarbageCollector_CollectionCount{job=\\\"httpfs-gateway-svc\\\", pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}[$__rate_interval])\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"stage: {{name}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"GC Rate\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"java_lang_GarbageCollector_CollectionTime\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"dtdurationms\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":12,\"x\":12,\"y\":11},\"id\":24,\"links\":[],\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"rate(java_lang_GarbageCollector_CollectionTime{job=\\\"httpfs-gateway-svc\\\", pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}[$__rate_interval])\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"stage: {{name}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"GC time (per second)\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"bytes\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":12,\"x\":0,\"y\":19},\"id\":34,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\",\"max\",\"min\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"java_lang_Memory_HeapMemoryUsage_used{job=\\\"httpfs-gateway-svc\\\", pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"used: heap\",\"range\":true,\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"java_lang_Memory_HeapMemoryUsage_committed{job=\\\"httpfs-gateway-svc\\\", pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}\",\"format\":\"time_series\",\"hide\":false,\"intervalFactor\":1,\"legendFormat\":\"commit: heap\",\"range\":true,\"refId\":\"C\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"java_lang_Memory_HeapMemoryUsage_max{job=\\\"httpfs-gateway-svc\\\", pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}\",\"format\":\"time_series\",\"hide\":false,\"intervalFactor\":1,\"legendFormat\":\"max: heap\",\"range\":true,\"refId\":\"B\"}],\"title\":\"Heap Memory \",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"bytes\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":12,\"x\":12,\"y\":19},\"id\":71,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\",\"max\",\"min\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"java_lang_Memory_NonHeapMemoryUsage_used{job=\\\"httpfs-gateway-svc\\\", pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"used: non-heap\",\"range\":true,\"refId\":\"B\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"java_lang_Memory_NonHeapMemoryUsage_committed{job=\\\"httpfs-gateway-svc\\\", pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}\",\"format\":\"time_series\",\"hide\":false,\"intervalFactor\":1,\"legendFormat\":\"commit: non-heap\",\"range\":true,\"refId\":\"D\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"java_lang_Memory_NonHeapMemoryUsage_max{job=\\\"httpfs-gateway-svc\\\", pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}\",\"format\":\"time_series\",\"hide\":false,\"intervalFactor\":1,\"legendFormat\":\"max: non-heap\",\"range\":true,\"refId\":\"A\"}],\"title\":\"NonHeap Memory \",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"java_lang_MemoryPool_Usage_used\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"bytes\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":12,\"x\":0,\"y\":27},\"id\":28,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\",\"max\",\"min\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"java_lang_MemoryPool_Usage_used{job=\\\"httpfs-gateway-svc\\\", pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\" {{name}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"Memory Pool Used\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"java_lang_MemoryPool_Usage_committed\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"bytes\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":12,\"x\":12,\"y\":27},\"id\":30,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\",\"max\",\"min\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"java_lang_MemoryPool_Usage_committed{job=\\\"httpfs-gateway-svc\\\", pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"name: {{name}}\",\"refId\":\"A\"}],\"title\":\"Memory Pool Committed\",\"type\":\"timeseries\"}],\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"refId\":\"A\"}],\"title\":\"JVM Memory\",\"type\":\"row\"},{\"collapsed\":true,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":11},\"id\":46,\"panels\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"busy:  The number of threads currently processing requests \\\\n\\nThe maximum number of threads to be created by the connector and made available for requests\\t\\n\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":24,\"x\":0,\"y\":12},\"id\":54,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"Catalina_ThreadPool_currentThreadCount{pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"current  total  threads\",\"range\":true,\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"Catalina_ThreadPool_currentThreadsBusy{pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\" busy\",\"range\":true,\"refId\":\"B\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"Catalina_ThreadPool_running{pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}\",\"format\":\"time_series\",\"hide\":false,\"intervalFactor\":1,\"legendFormat\":\"running\",\"range\":true,\"refId\":\"H\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"Catalina_ThreadPool_connectionCount{pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"connection\",\"range\":true,\"refId\":\"C\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"Catalina_ThreadPool_keepAliveCount{pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"keepAlive\",\"range\":true,\"refId\":\"D\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"Catalina_ThreadPool_maxThreads{pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}\",\"format\":\"time_series\",\"hide\":false,\"intervalFactor\":1,\"legendFormat\":\"max\",\"range\":true,\"refId\":\"E\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"Catalina_ThreadPool_acceptCount{pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}\",\"format\":\"time_series\",\"hide\":false,\"intervalFactor\":1,\"legendFormat\":\"accept\",\"range\":true,\"refId\":\"F\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"Catalina_ThreadPool_minSpareThreads{pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}\",\"format\":\"time_series\",\"hide\":false,\"intervalFactor\":1,\"legendFormat\":\"min spare\",\"range\":true,\"refId\":\"G\"}],\"title\":\"ThreadPool\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Catalina_GlobalRequestProcessor_bytesReceived /  Catalina_GlobalRequestProcessor_bytesSent\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"binBps\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":8,\"x\":0,\"y\":20},\"id\":48,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"rate(Catalina_GlobalRequestProcessor_bytesReceived{job=\\\"httpfs-gateway-svc\\\", pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}[$__rate_interval])\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"received\",\"range\":true,\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"rate(Catalina_GlobalRequestProcessor_bytesSent{job=\\\"httpfs-gateway-svc\\\", pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}[$__rate_interval])\",\"format\":\"time_series\",\"hide\":false,\"intervalFactor\":1,\"legendFormat\":\"sent\",\"range\":true,\"refId\":\"B\"}],\"title\":\"Request bytes\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"decimals\":2,\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"cps\"},\"overrides\":[{\"matcher\":{\"id\":\"byRegexp\",\"options\":\"/.*error/\"},\"properties\":[{\"id\":\"custom.transform\",\"value\":\"negative-Y\"}]}]},\"gridPos\":{\"h\":8,\"w\":8,\"x\":8,\"y\":20},\"id\":50,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\",\"max\",\"min\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"rate(Catalina_GlobalRequestProcessor_requestCount{ pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}[$__rate_interval])\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"total request\",\"range\":true,\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"rate(Catalina_GlobalRequestProcessor_errorCount{pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}[$__rate_interval])\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"error request\",\"range\":true,\"refId\":\"B\"}],\"title\":\"Requests\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Catalina_GlobalRequestProcessor_processingTime\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"ms\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":8,\"x\":16,\"y\":20},\"id\":52,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\",\"max\",\"min\"],\"displayMode\":\"table\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"rate(Catalina_GlobalRequestProcessor_processingTime{job=\\\"httpfs-gateway-svc\\\", pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}[$__rate_interval])\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"Request Processing Time\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Catalina_Servlet_requestCount\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"decimals\":2,\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"reqps\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":12,\"x\":0,\"y\":28},\"id\":64,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\",\"max\",\"min\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"none\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"topk(5, rate(Catalina_Servlet_requestCount{pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}[$__rate_interval]))\",\"format\":\"time_series\",\"interval\":\"60s\",\"intervalFactor\":1,\"legendFormat\":\"WebModule: {{WebModule}} Name: {{name}}\",\"refId\":\"A\"}],\"title\":\"Top 5 servlet request (rate)\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Catalina_Servlet_errorCount\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"decimals\":2,\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"reqps\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":12,\"x\":12,\"y\":28},\"id\":66,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\",\"max\",\"min\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"topk(5, rate(Catalina_Servlet_errorCount{job=\\\"httpfs-gateway-svc\\\", pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}[$__rate_interval]))\",\"format\":\"time_series\",\"interval\":\"60s\",\"intervalFactor\":1,\"legendFormat\":\"WebModule: {{WebModule}} Name: {{name}}\",\"refId\":\"A\"}],\"title\":\"Top 5 servlet error (rate)\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Catalina_Servlet_processingTime  /  Catalina_Servlet_requestCount\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"ms\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":12,\"x\":0,\"y\":36},\"id\":68,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\",\"max\",\"min\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"topk(5, rate(Catalina_Servlet_processingTime{pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}[$__rate_interval]))\",\"format\":\"time_series\",\"interval\":\"60s\",\"intervalFactor\":1,\"legendFormat\":\"WebModule: {{WebModule}}  -   Name: {{name}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"Top 5 servlets average processing time per request\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Catalina_Manager_expiredSessions  /   Catalina_Manager_rejectedSessions\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":12,\"x\":12,\"y\":36},\"id\":70,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"table\",\"placement\":\"right\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"sum(rate(Catalina_Manager_expiredSessions{pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}[$__rate_interval])) \",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"expired\",\"refId\":\"B\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"expr\":\"sum(rate(Catalina_Manager_rejectedSessions{pod=~\\\"$pod\\\", namespace=\\\"$namespace\\\"}[$__rate_interval]))\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"rejected\",\"refId\":\"C\"}],\"title\":\"Catalina Manager Sessions\",\"type\":\"timeseries\"}],\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"refId\":\"A\"}],\"title\":\"Catalina\",\"type\":\"row\"}],\"refresh\":\"\",\"schemaVersion\":36,\"style\":\"dark\",\"tags\":[],\"templating\":{\"list\":[{\"current\":{\"selected\":false,\"text\":\"Prometheus\",\"value\":\"Prometheus\"},\"hide\":0,\"includeAll\":false,\"multi\":false,\"name\":\"datasource\",\"options\":[],\"query\":\"prometheus\",\"queryValue\":\"\",\"refresh\":1,\"regex\":\"\",\"skipUrlSync\":false,\"type\":\"datasource\"},{\"current\":{\"selected\":false,\"text\":\"admin\",\"value\":\"admin\"},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"definition\":\"label_values(up{job=\\\"httpfs-gateway-svc\\\"}, namespace)\",\"hide\":0,\"includeAll\":false,\"multi\":false,\"name\":\"namespace\",\"options\":[],\"query\":{\"query\":\"label_values(up{job=\\\"httpfs-gateway-svc\\\"}, namespace)\",\"refId\":\"StandardVariableQuery\"},\"refresh\":1,\"regex\":\"\",\"skipUrlSync\":false,\"sort\":0,\"type\":\"query\"},{\"current\":{\"selected\":true,\"text\":\"All\",\"value\":\"$__all\"},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"definition\":\"label_values(up{job=\\\"httpfs-gateway-svc\\\",namespace=\\\"${namespace}\\\"}, pod)\",\"hide\":0,\"includeAll\":true,\"label\":\"pod\",\"multi\":false,\"name\":\"pod\",\"options\":[],\"query\":{\"query\":\"label_values(up{job=\\\"httpfs-gateway-svc\\\",namespace=\\\"${namespace}\\\"}, pod)\",\"refId\":\"StandardVariableQuery\"},\"refresh\":2,\"regex\":\"\",\"skipUrlSync\":false,\"sort\":0,\"tagValuesQuery\":\"\",\"tagsQuery\":\"\",\"type\":\"query\",\"useTags\":false}]},\"time\":{\"from\":\"now-5m\",\"to\":\"now\"},\"timepicker\":{\"hidden\":false,\"nowDelay\":\"\",\"refresh_intervals\":[\"1m\",\"5m\",\"15m\",\"30m\",\"1h\",\"2h\",\"1d\"],\"time_options\":[\"5m\",\"15m\",\"1h\",\"6h\",\"12h\",\"24h\",\"2d\",\"7d\",\"30d\"]},\"timezone\":\"\",\"title\":\"httpfs-gateway(catalina)\",\"uid\":\"httpfs_gateway\",\"version\":13,\"weekStart\":\"\"}"
						}
					}]
				},
				{
					"name": context.namespace + "-" + context.name + "-context"
					"type": "k8s-objects"
					"properties": objects: [{
						"apiVersion": "bdc.kdp.io/v1alpha1"
						"kind":       "ContextSetting"
						"metadata": {
							"name": context.namespace + "-" + context.name + "-context"
							"annotations": {
								"setting.ctx.bdc.kdp.io/type":   "httpfs"
								"setting.ctx.bdc.kdp.io/origin": "system"
							}
						}
						"spec": {
							"name": "httpfs-gateway-context"
							"type": "httpfs"
							"properties": {
								host:     "httpfs-gateway-svc.\(context.namespace).svc.cluster.local:14000"
								hostname: "httpfs-gateway-svc.\(context.namespace).svc.cluster.local"
								port:     "14000"
							}
						}
					}]
				},
			]

		}
	}

	parameter: {
		// +ui:order=1
		// +ui:description=组件依赖
		// +ui:title=组件依赖
		dependencies: {
			// +ui:order=5
			// +ui:description=httpfs 服务配置
			httpfs: {
				// +ui:order=1
				// +ui:description=httpfs依赖的hdfs配置，需先安装HDFS
				// +err:options={"required":"请先安装HDFS"}
				hdfsContext: string
			}
		}
		// +ui:order=2
		// +minimum=1
		// +ui:description=副本数
		replicas: *1 | int
		// +ui:order=3
		// +ui:description=资源规格
		resources: {
			// +ui:order=1
			// +ui:description=预留
			requests: {
				// +ui:order=1
				// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
				// +err:options={"pattern":"请输入正确的CPU格式，如0.25，250m"}
				// +ui:description=CPU
				cpu: *"0.25" | string
				// +ui:order=2
				// +pattern=^[1-9]\d*(Mi|Gi)$
				// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
				// +ui:description=内存
				memory: *"1Gi" | string
			}
			// +ui:order=2
			// +ui:description=限制
			limits: {
				// +ui:order=1
				// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
				// +err:options={"pattern":"请输入正确的CPU格式，如0.25，250m"}
				// +ui:description=CPU
				cpu: *"1" | string
				// +ui:order=2
				// +pattern=^[1-9]\d*(Mi|Gi)$
				// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
				// +ui:description=内存
				memory: *"1Gi" | string
			}
		}
		// +ui:order=100
		// +ui:options={"disabled":true}
		// +ui:description=镜像版本
		image: *"httpfs-gateway:v1.0.0-2.8.5" | string
	}
}
