import "strings"

"juicefs": {
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
			{
				name:        "minio.contextSetting"
				type:        "ContextSetting"
				refType:     "minio"
				refKey:      ""
				description: ""
				required:    true
			},
			{
				name:        "minio.contextSecret"
				type:        "ContextSecret"
				refType:     "minio"
				refKey:      ""
				description: ""
				required:    true
			},

		]
		apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "Application"
				type:       "juicefs-s3-gateway"
			}
		}
	}
	description: "juicefs-s3-gateway"
	type:        "xdefinition"
}

template: {
	_databaseName:  "\(strings.Replace(context.namespace+"_juicefs", "-", "_", -1))"
	_imageRegistry: *"" | string
	if context.docker_registry != _|_ && len(context.docker_registry) > 0 {
		_imageRegistry: context.docker_registry + "/"
	}
	_ingressHost: context["name"] + "-" + context["namespace"] + "." + context["ingress.root_domain"]

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
						chart:           "juicefs-s3-gateway"
						releaseName:     context["name"]
						repoType:        "oci"
						targetNamespace: context["namespace"]
						url:             context["helm_repo_url"]
						values: {
							image: {
								repository: "\(_imageRegistry)juicedata/mount"
								tag:        "ce-v1.2.0"
							}
							replicaCount: parameter.replicaCount
							secret: {
								name:    "jfs-volume"
								storage: "minio"
								// Do not remove the empty string, otherwise the chart will not work
								accessKey: " "
								secretKey: " "
								bucket:    " "
							}
							if parameter.formatOptions != _|_ {
								formatOptions: parameter.formatOptions
							}
							options: parameter.options
							envs: [
								{
									name: "MYSQL_PASSWORD"
									valueFrom: {
										secretKeyRef: {
											key:  "MYSQL_PASSWORD"
											name: "\(parameter.mysql.mysqlSecret)"
										}
									}
								},
								{
									name: "MYSQL_USER"
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
								{
									name:  "METAURL"
									value: "mysql://$(MYSQL_USER):$(MYSQL_PASSWORD)@($(MYSQL_HOST):$(MYSQL_PORT))/$(DATABASE)"
								},
								{
									name: "MINIO_ROOT_PASSWORD"
									valueFrom: {
										secretKeyRef: {
											key:  "MINIO_ROOT_PASSWORD"
											name: "\(parameter.minio.contextSecret)"
										}
									}
								},
								{
									name: "MINIO_ROOT_USER"
									valueFrom: {
										secretKeyRef: {
											key:  "MINIO_ROOT_USER"
											name: "\(parameter.minio.contextSecret)"
										}
									}
								},
							]
							initEnvs: [
								{
									name: "MYSQL_PASSWORD"
									valueFrom: {
										secretKeyRef: {
											key:  "MYSQL_PASSWORD"
											name: "\(parameter.mysql.mysqlSecret)"
										}
									}
								},
								{
									name: "MYSQL_USER"
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
								{
									name:  "metaurl"
									value: "mysql://$(MYSQL_USER):$(MYSQL_PASSWORD)@($(MYSQL_HOST):$(MYSQL_PORT))/$(DATABASE)"
								},
								{
									name: "secretkey"
									valueFrom: {
										secretKeyRef: {
											key:  "MINIO_ROOT_PASSWORD"
											name: "\(parameter.minio.contextSecret)"
										}
									}
								},
								{
									name: "accesskey"
									valueFrom: {
										secretKeyRef: {
											key:  "MINIO_ROOT_USER"
											name: "\(parameter.minio.contextSecret)"
										}
									}
								},
								{
									name: "bucketHost"
									valueFrom: {
										configMapKeyRef: {
											key:  "host"
											name: "\(parameter.minio.contextSetting)"
										}
									}
								},
								{
									name:  "bucket"
									value: "http://$(bucketHost)/juicefs"
								},

							]

							if parameter.resources != _|_ {
								resources: parameter.resources
							}
							if parameter.affinity != _|_ {
								affinity: parameter.affinity
							}
						}
						version: "0.11.2"
					}
					traits: [
						{
							properties: {
								rules: [
									{
										host: _ingressHost
										paths: [
											{
												path:        "/"
												serviceName: "juicefs-s3-gateway"
												servicePort: 9000
											},
										]
									},

								]
								tls: [
									{
										hosts: [
											_ingressHost,
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
										path:     "/metrics"
										port:     9567
										portName: "metrics"
									},
								]
								monitortype: "service"
								namespace:   context["namespace"]
								matchLabels: {
									"app.kubernetes.io/instance": context.name
								}
							}
							type: "bdos-monitor"
						},
						{
							"type": "bdos-grafana-dashboard"
							"properties": {
								"labels": {
									"grafana_dashboard": "1"
								}
								"dashboard_data": {
									"juicefs-dashboard.json": "{\"annotations\":{\"list\":[{\"builtIn\":1,\"datasource\":{\"type\":\"datasource\",\"uid\":\"grafana\"},\"enable\":true,\"hide\":true,\"iconColor\":\"rgba(0,211,255,1)\",\"name\":\"Annotations&Alerts\",\"type\":\"dashboard\"}]},\"editable\":true,\"fiscalYearStartMonth\":0,\"gnetId\":20794,\"graphTooltip\":0,\"id\":130,\"links\":[],\"liveNow\":false,\"panels\":[{\"datasource\":{\"uid\":\"$datasource\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisBorderShow\":false,\"axisCenteredZero\":false,\"axisColorMode\":\"text\",\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"insertNulls\":false,\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"bytes\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":8,\"x\":0,\"y\":0},\"id\":2,\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"list\",\"placement\":\"bottom\",\"showLegend\":true},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"10.4.0\",\"targets\":[{\"datasource\":{\"uid\":\"$datasource\"},\"exemplar\":true,\"expr\":\"avg(juicefs_used_space{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"})\",\"format\":\"time_series\",\"instant\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"DataSize\",\"refId\":\"A\"}],\"title\":\"DataSize\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisBorderShow\":false,\"axisCenteredZero\":false,\"axisColorMode\":\"text\",\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"insertNulls\":false,\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"none\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":8,\"x\":8,\"y\":0},\"id\":4,\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"list\",\"placement\":\"bottom\",\"showLegend\":true},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"10.4.0\",\"targets\":[{\"datasource\":{\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"avg(juicefs_used_inodes{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"})\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"Files\",\"range\":true,\"refId\":\"A\"}],\"title\":\"Files\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisBorderShow\":false,\"axisCenteredZero\":false,\"axisColorMode\":\"text\",\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"insertNulls\":false,\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"none\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":8,\"x\":16,\"y\":0},\"id\":5,\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"list\",\"placement\":\"bottom\",\"showLegend\":true},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"10.4.0\",\"targets\":[{\"datasource\":{\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"expr\":\"count by(juicefs_version)(juicefs_uptime{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"})\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"Sessions\",\"range\":true,\"refId\":\"A\"}],\"title\":\"ClientSessions\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisBorderShow\":false,\"axisCenteredZero\":false,\"axisColorMode\":\"text\",\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"insertNulls\":false,\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":8,\"x\":0,\"y\":6},\"id\":8,\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"list\",\"placement\":\"bottom\",\"showLegend\":true},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"10.4.0\",\"targets\":[{\"datasource\":{\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(rate(juicefs_fuse_ops_durations_histogram_seconds_count{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"}[1m])<5000000000)by(instance)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"Ops{{instance}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"Operations\",\"type\":\"timeseries\"},{\"datasource\":{\"uid\":\"$datasource\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisBorderShow\":false,\"axisCenteredZero\":false,\"axisColorMode\":\"text\",\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"insertNulls\":false,\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"binBps\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":8,\"x\":8,\"y\":6},\"id\":7,\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"list\",\"placement\":\"bottom\",\"showLegend\":true},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"10.4.0\",\"targets\":[{\"datasource\":{\"uid\":\"$datasource\"},\"exemplar\":true,\"expr\":\"sum(rate(juicefs_fuse_written_size_bytes_sum{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"}[1m])<5000000000)by(instance)\",\"format\":\"time_series\",\"instant\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"Write{{instance}}\",\"refId\":\"A\"},{\"datasource\":{\"uid\":\"$datasource\"},\"expr\":\"sum(rate(juicefs_fuse_read_size_bytes_sum{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"}[1m])<5000000000)by(instance)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"Read{{instance}}\",\"refId\":\"B\"}],\"title\":\"IOThroughput\",\"type\":\"timeseries\"},{\"datasource\":{\"uid\":\"$datasource\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisBorderShow\":false,\"axisCenteredZero\":false,\"axisColorMode\":\"text\",\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"insertNulls\":false,\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"µs\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":8,\"x\":16,\"y\":6},\"id\":18,\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"list\",\"placement\":\"bottom\",\"showLegend\":true},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"10.4.0\",\"targets\":[{\"datasource\":{\"uid\":\"$datasource\"},\"expr\":\"sum(rate(juicefs_fuse_ops_durations_histogram_seconds_sum{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"}[1m]))by(instance,mp)*1000000/sum(rate(juicefs_fuse_ops_durations_histogram_seconds_count{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"}[1m]))by(instance,mp)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{instance}}:{{mp}}\",\"refId\":\"A\"}],\"title\":\"IOLatency\",\"type\":\"timeseries\"},{\"datasource\":{\"uid\":\"$datasource\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisBorderShow\":false,\"axisCenteredZero\":false,\"axisColorMode\":\"text\",\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"insertNulls\":false,\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":8,\"x\":0,\"y\":12},\"id\":13,\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"list\",\"placement\":\"bottom\",\"showLegend\":true},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"10.4.0\",\"targets\":[{\"datasource\":{\"uid\":\"$datasource\"},\"expr\":\"sum(rate(juicefs_transaction_durations_histogram_seconds_count{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"}[1m]))by(instance)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{instance}}\",\"refId\":\"A\"}],\"title\":\"Transactions\",\"type\":\"timeseries\"},{\"datasource\":{\"uid\":\"$datasource\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisBorderShow\":false,\"axisCenteredZero\":false,\"axisColorMode\":\"text\",\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"insertNulls\":false,\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"µs\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":8,\"x\":8,\"y\":12},\"id\":14,\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"list\",\"placement\":\"bottom\",\"showLegend\":true},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"10.4.0\",\"targets\":[{\"datasource\":{\"uid\":\"$datasource\"},\"expr\":\"sum(rate(juicefs_transaction_durations_histogram_seconds_sum{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"}[1m]))by(instance,mp)*1000000/sum(rate(juicefs_transaction_durations_histogram_seconds_count{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"}[1m]))by(instance,mp)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{instance}}:{{mp}}\",\"refId\":\"A\"}],\"title\":\"TransactionLatency\",\"type\":\"timeseries\"},{\"datasource\":{\"uid\":\"$datasource\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisBorderShow\":false,\"axisCenteredZero\":false,\"axisColorMode\":\"text\",\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"insertNulls\":false,\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"min\":0,\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":8,\"x\":16,\"y\":12},\"id\":20,\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"list\",\"placement\":\"bottom\",\"showLegend\":true},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"10.4.0\",\"targets\":[{\"datasource\":{\"uid\":\"$datasource\"},\"expr\":\"sum(rate(juicefs_transaction_restart{vol_name=~\\\"$name\\\",namespace=\\\"$namespace\\\"}[1m]))by(instance)\",\"format\":\"time_series\",\"intervalFactor\":1,\"legendFormat\":\"Restarts{{instance}}\",\"refId\":\"A\"}],\"title\":\"TransactionRestarts\",\"type\":\"timeseries\"},{\"datasource\":{\"uid\":\"$datasource\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisBorderShow\":false,\"axisCenteredZero\":false,\"axisColorMode\":\"text\",\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"insertNulls\":false,\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":8,\"x\":0,\"y\":18},\"id\":15,\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"list\",\"placement\":\"bottom\",\"showLegend\":true},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"10.4.0\",\"targets\":[{\"datasource\":{\"uid\":\"$datasource\"},\"expr\":\"sum(rate(juicefs_object_request_durations_histogram_seconds_count{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"}[1m]))by(method)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{method}}\",\"refId\":\"A\"},{\"datasource\":{\"uid\":\"$datasource\"},\"exemplar\":true,\"expr\":\"sum(rate(juicefs_object_request_errors{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"}[1m]))\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"errors\",\"refId\":\"B\"}],\"title\":\"ObjectsRequests\",\"type\":\"timeseries\"},{\"datasource\":{\"uid\":\"$datasource\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisBorderShow\":false,\"axisCenteredZero\":false,\"axisColorMode\":\"text\",\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"insertNulls\":false,\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"Bps\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":8,\"x\":8,\"y\":18},\"id\":17,\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"list\",\"placement\":\"bottom\",\"showLegend\":true},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"10.4.0\",\"targets\":[{\"datasource\":{\"uid\":\"$datasource\"},\"exemplar\":true,\"expr\":\"sum(rate(juicefs_object_request_data_bytes{method=\\\"PUT\\\",vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"}[1m]))by(instance,method)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{method}}{{instance}}\",\"refId\":\"A\"},{\"datasource\":{\"uid\":\"$datasource\"},\"exemplar\":true,\"expr\":\"sum(rate(juicefs_object_request_data_bytes{method=\\\"GET\\\",vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"}[1m]))by(instance,method)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{method}}{{instance}}\",\"refId\":\"B\"},{\"datasource\":{\"uid\":\"$datasource\"},\"exemplar\":true,\"expr\":\"sum(rate(juicefs_object_request_data_bytes{method=\\\"GET\\\",vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"}[1m]))\",\"hide\":false,\"interval\":\"\",\"legendFormat\":\"Total\",\"refId\":\"C\"}],\"title\":\"ObjectsThroughput\",\"type\":\"timeseries\"},{\"datasource\":{\"uid\":\"$datasource\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisBorderShow\":false,\"axisCenteredZero\":false,\"axisColorMode\":\"text\",\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"insertNulls\":false,\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"µs\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":8,\"x\":16,\"y\":18},\"id\":16,\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"list\",\"placement\":\"bottom\",\"showLegend\":true},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"10.4.0\",\"targets\":[{\"datasource\":{\"uid\":\"$datasource\"},\"expr\":\"sum(rate(juicefs_object_request_durations_histogram_seconds_sum{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"}[1m]))by(instance)*1000000/sum(rate(juicefs_object_request_durations_histogram_seconds_count{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"}[1m]))by(instance)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{instance}}\",\"refId\":\"A\"}],\"title\":\"ObjectsLatency\",\"type\":\"timeseries\"},{\"datasource\":{\"uid\":\"$datasource\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisBorderShow\":false,\"axisCenteredZero\":false,\"axisColorMode\":\"text\",\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"insertNulls\":false,\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"percent\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":8,\"x\":0,\"y\":24},\"id\":10,\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"list\",\"placement\":\"bottom\",\"showLegend\":true},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"10.4.0\",\"targets\":[{\"datasource\":{\"uid\":\"$datasource\"},\"exemplar\":true,\"expr\":\"sum(rate(juicefs_cpu_usage{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"}[1m])*100<1000)by(instance,mp)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{instance}}:{{mp}}\",\"refId\":\"A\"}],\"title\":\"ClientCPUUsage\",\"type\":\"timeseries\"},{\"datasource\":{\"uid\":\"$datasource\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisBorderShow\":false,\"axisCenteredZero\":false,\"axisColorMode\":\"text\",\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"insertNulls\":false,\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"bytes\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":8,\"x\":8,\"y\":24},\"id\":11,\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"list\",\"placement\":\"bottom\",\"showLegend\":true},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"10.4.0\",\"targets\":[{\"datasource\":{\"uid\":\"$datasource\"},\"expr\":\"sum(juicefs_memory{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"})by(instance,mp)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{instance}}:{{mp}}\",\"refId\":\"A\"}],\"title\":\"ClientMemoryUsage\",\"type\":\"timeseries\"},{\"datasource\":{\"uid\":\"$datasource\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisBorderShow\":false,\"axisCenteredZero\":false,\"axisColorMode\":\"text\",\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"insertNulls\":false,\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"none\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":8,\"x\":16,\"y\":24},\"id\":21,\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"list\",\"placement\":\"bottom\",\"showLegend\":true},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"10.4.0\",\"targets\":[{\"datasource\":{\"uid\":\"$datasource\"},\"expr\":\"sum(juicefs_go_goroutines{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"})by(instance,mp)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{instance}}:{{mp}}\",\"refId\":\"A\"}],\"title\":\"Gothreads\",\"type\":\"timeseries\"},{\"datasource\":{\"uid\":\"$datasource\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisBorderShow\":false,\"axisCenteredZero\":false,\"axisColorMode\":\"text\",\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"insertNulls\":false,\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"bytes\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":8,\"x\":0,\"y\":30},\"id\":22,\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"list\",\"placement\":\"bottom\",\"showLegend\":true},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"10.4.0\",\"targets\":[{\"datasource\":{\"uid\":\"$datasource\"},\"exemplar\":true,\"expr\":\"sum(juicefs_blockcache_bytes{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"})by(instance,mp)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{instance}}:{{mp}}\",\"refId\":\"A\"}],\"title\":\"BlockCacheSize\",\"type\":\"timeseries\"},{\"datasource\":{\"uid\":\"$datasource\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisBorderShow\":false,\"axisCenteredZero\":false,\"axisColorMode\":\"text\",\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"insertNulls\":false,\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"none\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":8,\"x\":8,\"y\":30},\"id\":23,\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"list\",\"placement\":\"bottom\",\"showLegend\":true},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"10.4.0\",\"targets\":[{\"datasource\":{\"uid\":\"$datasource\"},\"exemplar\":true,\"expr\":\"sum(juicefs_blockcache_blocks{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"})by(instance,mp)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{instance}}:{{mp}}\",\"refId\":\"A\"}],\"title\":\"BlockCacheCount\",\"type\":\"timeseries\"},{\"datasource\":{\"uid\":\"$datasource\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisBorderShow\":false,\"axisCenteredZero\":false,\"axisColorMode\":\"text\",\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"insertNulls\":false,\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"percent\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":8,\"x\":16,\"y\":30},\"id\":24,\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"list\",\"placement\":\"bottom\",\"showLegend\":true},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"10.4.0\",\"targets\":[{\"datasource\":{\"uid\":\"$datasource\"},\"exemplar\":true,\"expr\":\"sum(rate(juicefs_blockcache_hits{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"}[1m]))by(instance,mp)*100/(sum(rate(juicefs_blockcache_hits{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"}[1m]))by(instance,mp)+sum(rate(juicefs_blockcache_miss{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"}[1m]))by(instance,mp))\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"Hits{{instance}}:{{mp}}\",\"refId\":\"A\"},{\"datasource\":{\"uid\":\"$datasource\"},\"exemplar\":true,\"expr\":\"sum(rate(juicefs_blockcache_hit_bytes{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"}[1m]))by(instance,mp)*100/(sum(rate(juicefs_blockcache_hit_bytes{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"}[1m]))by(instance,mp)+sum(rate(juicefs_blockcache_miss_bytes{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"}[1m]))by(instance,mp))\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"HitBytes{{instance}}:{{mp}}\",\"refId\":\"B\"}],\"title\":\"BlockCacheHitRatio\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisBorderShow\":false,\"axisCenteredZero\":false,\"axisColorMode\":\"text\",\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"insertNulls\":false,\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"min\":0,\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"percent\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":8,\"x\":0,\"y\":36},\"id\":25,\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"list\",\"placement\":\"bottom\",\"showLegend\":true},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"10.4.0\",\"targets\":[{\"datasource\":{\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(rate(juicefs_compact_size_histogram_bytes_count{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"}[1m]))by(instance,mp)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{instance}}:{{mp}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"Compaction\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisBorderShow\":false,\"axisCenteredZero\":false,\"axisColorMode\":\"text\",\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"insertNulls\":false,\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"min\":0,\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"percent\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":8,\"x\":8,\"y\":36},\"id\":26,\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"list\",\"placement\":\"bottom\",\"showLegend\":true},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"10.4.0\",\"targets\":[{\"datasource\":{\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(rate(juicefs_compact_size_histogram_bytes_sum{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"}[1m]))by(instance,mp)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{instance}}:{{mp}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"CompactedData\",\"type\":\"timeseries\"},{\"datasource\":{\"uid\":\"$datasource\"},\"description\":\"\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisBorderShow\":false,\"axisCenteredZero\":false,\"axisColorMode\":\"text\",\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"insertNulls\":false,\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":8,\"x\":16,\"y\":36},\"id\":27,\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\"],\"displayMode\":\"list\",\"placement\":\"bottom\",\"showLegend\":true},\"tooltip\":{\"mode\":\"single\",\"sort\":\"none\"}},\"pluginVersion\":\"10.4.0\",\"targets\":[{\"datasource\":{\"uid\":\"$datasource\"},\"exemplar\":true,\"expr\":\"sum(juicefs_fuse_open_handlers{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"})by(instance,mp)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{instance}}:{{mp}}\",\"refId\":\"A\"}],\"title\":\"OpenFileHandlers\",\"type\":\"timeseries\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisBorderShow\":false,\"axisCenteredZero\":false,\"axisColorMode\":\"text\",\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"insertNulls\":false,\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"normal\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"min\":0,\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"short\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":8,\"x\":0,\"y\":42},\"id\":28,\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\",\"showLegend\":false},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"10.4.0\",\"targets\":[{\"datasource\":{\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"expr\":\"juicefs_staging_blocks{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"}\",\"legendFormat\":\"{{instance}}:{{mp}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"JuicefsStagingBlocks\",\"type\":\"timeseries\"},{\"datasource\":{\"uid\":\"$datasource\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisBorderShow\":false,\"axisCenteredZero\":false,\"axisColorMode\":\"text\",\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"insertNulls\":false,\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"normal\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"min\":0,\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"bytes\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":8,\"x\":8,\"y\":42},\"id\":29,\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\",\"showLegend\":true},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"10.4.0\",\"targets\":[{\"datasource\":{\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"juicefs_staging_block_bytes{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"}\",\"legendFormat\":\"{{instance}}:{{mp}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"JuicefsStagingBlockUsage\",\"type\":\"timeseries\"},{\"datasource\":{\"uid\":\"$datasource\"},\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisBorderShow\":false,\"axisCenteredZero\":false,\"axisColorMode\":\"text\",\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"insertNulls\":false,\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"min\":0,\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\"},{\"color\":\"red\",\"value\":80}]},\"unit\":\"s\",\"unitScale\":true},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":8,\"x\":16,\"y\":42},\"id\":30,\"options\":{\"legend\":{\"calcs\":[],\"displayMode\":\"list\",\"placement\":\"bottom\",\"showLegend\":true},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"10.4.0\",\"targets\":[{\"datasource\":{\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(rate(juicefs_staging_block_delay_seconds{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"}[1m]))by(instance,mp)/sum(rate(juicefs_object_request_durations_histogram_seconds_count{vol_name=\\\"$name\\\",namespace=\\\"$namespace\\\"}[1m]))by(instance,mp)\",\"hide\":false,\"legendFormat\":\"{{instance}}:{{mp}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"JuicefsStagingBlockDelay\",\"type\":\"timeseries\"}],\"refresh\":\"\",\"schemaVersion\":39,\"tags\":[\"juicefs\",\"s3\"],\"templating\":{\"list\":[{\"current\":{\"selected\":false,\"text\":\"Prometheus\",\"value\":\"prometheus\"},\"hide\":0,\"includeAll\":false,\"multi\":false,\"name\":\"datasource\",\"options\":[],\"query\":\"prometheus\",\"queryValue\":\"\",\"refresh\":1,\"regex\":\"\",\"skipUrlSync\":false,\"type\":\"datasource\"},{\"current\":{\"selected\":false,\"text\":\"kdp-data\",\"value\":\"kdp-data\"},\"datasource\":{\"uid\":\"${datasource}\"},\"definition\":\"label_values(juicefs_uptime,namespace)\",\"hide\":0,\"includeAll\":false,\"multi\":false,\"name\":\"namespace\",\"options\":[],\"query\":{\"qryType\":1,\"query\":\"label_values(juicefs_uptime,namespace)\",\"refId\":\"PrometheusVariableQueryEditor-VariableQuery\"},\"refresh\":1,\"regex\":\"\",\"skipUrlSync\":false,\"sort\":0,\"type\":\"query\"},{\"current\":{\"selected\":false,\"text\":\"jfs-volume\",\"value\":\"jfs-volume\"},\"datasource\":{\"uid\":\"${datasource}\"},\"definition\":\"label_values(juicefs_uptime,vol_name)\",\"hide\":0,\"includeAll\":false,\"multi\":false,\"name\":\"name\",\"options\":[],\"query\":{\"query\":\"label_values(juicefs_uptime,vol_name)\",\"refId\":\"StandardVariableQuery\"},\"refresh\":1,\"regex\":\"\",\"skipUrlSync\":false,\"sort\":0,\"type\":\"query\"}]},\"time\":{\"from\":\"now-5m\",\"to\":\"now\"},\"timepicker\":{\"refresh_intervals\":[\"30s\",\"1m\",\"5m\",\"15m\",\"30m\",\"1h\",\"2h\",\"1d\"],\"time_options\":[\"5m\",\"15m\",\"1h\",\"6h\",\"12h\",\"24h\",\"2d\",\"7d\",\"30d\"]},\"timezone\":\"\",\"title\":\"JuiceFS Dashboard\",\"uid\":\"juicefs\",\"version\":2,\"weekStart\":\"\"}"
								}
							}
						},
					]
					type: "helm"
				},
				{
					name: context["name"] + "-context"
					type: "k8s-objects"
					properties: {
						objects: [{
							apiVersion: "bdc.kdp.io/v1alpha1"
							kind:       "ContextSetting"
							metadata: {
								annotations: {
									"setting.ctx.bdc.kdp.io/origin": "system"
									"setting.ctx.bdc.kdp.io/type":   "juicefs-s3-gateway"
								}
								name:      context["namespace"] + "-" + context["name"] + "-context-setting"
								namespace: context["namespace"]
							}
							spec: {
								name:      context["name"] + "-context-setting"
								_port:     "9000"
								_hostname: context["name"] + "." + context["namespace"] + ".svc.cluster.local"
								properties: {
									hostname: _hostname
									port:     _port
									host:     _hostname + ":" + _port
								}
								type: "juicefs-s3-gateway"
							}
						}]
					}
				},
				{	
					_jobName: context["name"] + "-create-database"
					name: _jobName
					type: "k8s-objects"
					properties: {
						objects: [{
							apiVersion: "batch/v1"
							kind:       "Job"
							metadata: name: _jobName
							labels: {
								app:                  context.name
								"app.core.bdos/type": "system"
							}
							spec: {
								ttlSecondsAfterFinished: 180
								template: spec: {
									containers: [{
										name:  "create-mysql-database"
										image: _imageRegistry + "bitnami/mysql:8.0.22"
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
									}]
									restartPolicy: "Never"
								}}
						}]
					}
				},

			]
			policies: [
				{
					type: "apply-once"
					name: "apply-once-res"
					properties: rules: [
						{
							selector: resourceTypes: ["Namespace", "Job"]
							strategy: {
								path: ["*"]
							}
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

		// +ui:description=MinIO依赖
		// +ui:order=2
		minio: {
			// +ui:description=MinIO 连接信息
			// +err:options={"required":"请先安装minio"}
			contextSetting: string
			// +ui:description=MinIO 认证信息
			// +err:options={"required":"请先安装minio"}
			contextSecret: string
		}

		// +minimum=1
		// +ui:description=副本数
		// +ui:order=3
		replicaCount: *1 | int

		// +ui:description=资源规格
		// +ui:order=4
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

		// +ui:description=格式化选项，使用空格分隔。Ref: https://juicefs.com/docs/community/command_reference#format。Example: Example: "--inodes=1000000 --block-size=4M"
		// +ui:order=5
		formatOptions?: string
		// +ui:description=Gateway配置选项，使用空格分隔。Ref: https://juicefs.com/docs/community/command_reference#gateway。Example: "--get-timeout=60 --put-timeout=60" 
		// +ui:order=6
		options: *"--multi-buckets=true --cache-partial-only=true --cache-size=10240" | string

		// +ui:description=配置kubernetes亲和性和反亲和性，请根据实际情况调整
		// +ui:order=7
		affinity?: {}

	}
}
