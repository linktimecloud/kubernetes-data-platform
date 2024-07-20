import ("strings")

"hive-server2": {
	annotations: {}
	labels: {}
	attributes: {
		"dynamicParameterMeta": [
			{
				"name":        "dependencies.hdfsConfigMapName"
				"type":        "ContextSetting"
				"refType":     "hdfs"
				"refKey":      ""
				"description": "hdfs config name"
				"required":    true
			},
			{
				"name":        "dependencies.hmsConfigMapName"
				"type":        "ContextSetting"
				"refType":     "hive-metastore"
				"refKey":      ""
				"description": "hive metastore config name"
				"required":    true
			},
			{
				"name":        "dependencies.zookeeperQuorum"
				"type":        "ContextSetting"
				"refType":     "zookeeper"
				"refKey":      "host"
				"description": "zookeeper host"
				"required":    true
			},
		]
		apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "Application"
				type:       "hive-server2"
			}
		}
	}
	description: "hive-server2 xdefinition"
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
					"type": "k8s-objects"
					"properties": {
						"objects": [
							{
								apiVersion: "apps/v1"
								kind:       "StatefulSet"
								metadata: {
									name: context.name
									annotations: {
										"app.core.bdos/catalog":     "hive"
										"reloader.stakater.com/auto": "true"
									}
									labels: {
										"app": context.name
										"app.core.bdos/type": "system"
									}
								}
								spec: {
									replicas: parameter.replicas
									selector: matchLabels: app: context.name
									serviceName: context.name
									template: {
										metadata: labels: app: context.name
										spec: {
											_initContainers: [...]
											initContainers: _initContainers
											containers: [{
												name: context.name
												env: [{
													name: "HIVE_METASTORE_ADDRESS"
													valueFrom: configMapKeyRef: {
														name: parameter.dependencies.hmsConfigMapName
														key:  "host"
													}
												}]
												command: ["/bin/bash", "-c", "/hs2/sbin/run.sh"]
												image: "\(context.docker_registry)/\(parameter.image)"
												livenessProbe: {
													exec: {
														command: ["bash", "/hs2/sbin/healthcheck.sh"]
													}
													periodSeconds: 30
													failureThreshold: 6
													timeoutSeconds: 10
												}
												startupProbe: {
													tcpSocket: {
														port: 10000
													}
													failureThreshold: 12
													periodSeconds: 10
												}
												resources: parameter.resources
												ports: [{
													containerPort: 10000
													protocol:      "TCP"
												}, {
													containerPort: 10001
													protocol:      "TCP"
												}, {
													containerPort: 10002
													protocol:      "TCP"
												}, {
													containerPort: 9008
													protocol:      "TCP"
												}]
												volumeMounts: [{
													name:      "logs"
													mountPath: "/tmp/root"
												}, {
													name: "hdfs-conf"
													mountPath: "/opt/hadoop/etc/hadoop"
													readOnly: true
												}, {
													name: "hive-server-conf"
													mountPath: "/tmp/hive/conf/"
													readOnly: true
												}, {
													name: "hs2-scripts"
													mountPath: "/hs2/sbin/"
													readOnly: true
												}]
											}]
											volumes: [{
												name: "logs"
												emptyDir: {}
											}, {
												name: "hdfs-conf"
												configMap: {
													name: parameter.dependencies.hdfsConfigMapName
												}
											}, {
												name: "hive-server-conf"
												configMap: {
													name: context.name + "-server-conf"
												}
											}, {
												name: "hs2-scripts"
												configMap: {
													name: context.name + "-scripts"
													defaultMode: 484
												}
											}]
										}
									}
								}
							},
							{
								apiVersion: "v1"
								kind: "ConfigMap"
								metadata: {
									name: context.name + "-scripts"
									labels: {
										"app": context.name
									}
								}
								data: {
									"run.sh": """
									#!/usr/bin/env bash
									set -e

									INDEX=${HOSTNAME##*-}

									cp /tmp/hive/conf/hive-site.xml /opt/hive/conf/hive-site.xml
									cp /tmp/hive/conf/spark-defaults.conf /opt/hive/conf/spark-defaults.conf
									cp /tmp/hive/conf/hive-log4j2.properties /opt/hive/conf/hive-log4j2.properties
									cp /tmp/hive/conf/executorPodTemplate.yaml /opt/hive/conf/executorPodTemplate.yaml

									sed -i "s#__INDEX__#${INDEX}#g" /opt/hive/conf/hive-site.xml
									sed -i "s#__HMS_ADDRESS__#${HIVE_METASTORE_ADDRESS}#g" /opt/hive/conf/hive-site.xml
									sed -i "s#__INDEX__#${INDEX}#g" /opt/hive/conf/spark-defaults.conf

									sed -i "s#__HOSTNAME__#${HOSTNAME}#"  /opt/hive/conf/hive-log4j2.properties
									cp /opt/hive/conf/*.xml /opt/spark/conf/
									echo "Starting the HiveServer2 service"
									export HADOOP_CLIENT_OPTS="$HADOOP_CLIENT_OPTS -javaagent:/prometheus/jmx_prometheus_javaagent-0.17.2.jar=9008:/usr/app/jmx_prometheus/hs2-jmx-exporter.yml -Dcom.sun.management.jmxremote.ssl=false -Dcom.amazonaws.sdk.disableCertChecking=true"
									/opt/hive/bin/hive --service hiveserver2
									"""

									"healthcheck.sh": """
									#!/usr/bin/env bash

									### check hms
									array=(${HIVE_METASTORE_ADDRESS//,/ })
									for address in ${array[@]}
									do
										echo $address
										port=9083
										echo "exit"|nc $address $port
										result=$?
										if [[ $result -ne 0 ]]; then
											echo "#####WARN#####check hms $address:$port failed!Please confirm that hms is normal."
										fi
									done

									### check zookeeper
									INDEX=${HOSTNAME##*-}
									HS2_HOSTNAME=\(context.name)-$INDEX.\(context.name).\(context.namespace).svc.cluster.local
									hive_file="/opt/hive/conf/hive-site.xml"
									ZOOKEEPER_ENABLED=`awk '/>hive.server2.support.dynamic.service.discovery</{getline a;print a}' $hive_file | grep -oP '(?<=<value>).*(?=</value>)'`
									if [[ "$ZOOKEEPER_ENABLED"x = "true"x ]]; then
										zookeeper=`awk '/>hive.zookeeper.quorum</{getline a;print a}' $hive_file | grep -oP '(?<=<value>).*(?=</value>)'`
										namespace=`awk '/>hive.server2.zookeeper.namespace</{getline a;print a}' $hive_file | grep -oP '(?<=<value>).*(?=</value>)'`
										echo "zookeeper is $zookeeper and namespace is $namespace"
										/usr/local/zookeeper/bin/zkCli.sh -timeout 5000 -server $zookeeper ls /$namespace | grep $HS2_HOSTNAME:10000 | tee check_znode.log
										if [ ${PIPESTATUS[0]} -eq 0 ]; then
											if [ `cat check_znode.log | wc -l` -eq '0' ]; then
												echo "path /$namespace/$HS2_HOSTNAME:10000 is not exist in zookeeper $zookeeper"
												exit 3
											else
												echo "check znode in $zk success"
												exit 0
											fi
										else
											echo "connect $zookeeper failed,please check zookeeper is normal"
											exit 5
										fi
									fi
									"""
								}
							},
							{
								apiVersion: "v1"
								kind: "ConfigMap"
								metadata: {
									name: context.name + "-server-conf"
									labels: {
										"app": context.name
									}
								}
								data: {
									_commonConf: {
										"hive.metastore.uris": "thrift://__HMS_ADDRESS__:9083"
										"hive.zookeeper.quorum": parameter.dependencies.zookeeperQuorum
										"hive.server2.zookeeper.namespace": "\(context.namespace)_hiveserver2/server"
										"hive.server2.thrift.bind.host": "\(context.name)-__INDEX__.\(context.name).\(context.namespace).svc.cluster.local"
										"hive.spark.client.rpc.server.address": "\(context.name)-__INDEX__.\(context.name).\(context.namespace).svc.cluster.local"
									}
									_commonConfStr: "\n\t\(strings.Join([for k, v in _commonConf {"<property>\n\t\t<name>\(k)</name>\n\t\t<value>\(v)</value>\n\t</property>"}], "\n\t"))"
									
									"hive-site.xml": """
									<?xml version="1.0"?>
									<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
									<configuration>
										\(strings.Join([for k, v in parameter.hiveConf{"<property>\n\t\t<name>\(k)</name>\n\t\t<value>\(v)</value>\n\t</property>"}], "\n\t") + _commonConfStr)
									</configuration>
									"""

									_sparkDataLocalityConf: *"" | string
									if parameter.dataLocality {
										_sparkDataLocalityConf: "spark.kubernetes.executor.podTemplateFile=/opt/hive/conf/executorPodTemplate.yaml" 
									}
									"spark-defaults.conf": """
									spark.master k8s://https://kubernetes.default.svc.cluster.local:443
									spark.kubernetes.master https://kubernetes.default.svc.cluster.local:443
									spark.rpcserver.address \(context.name)-__INDEX__.\(context.name).\(context.namespace).svc.cluster.local
									spark.kubernetes.container.image \(context.docker_registry)/\(parameter.spark.image)
									spark.kubernetes.namespace \(context.namespace)
									spark.kubernetes.authenticate.driver.serviceAccountName hive-spark
									spark.kubernetes.hadoop.configMapName \(parameter.dependencies.hdfsConfigMapName)
									spark.kubernetes.driver.label.spark-native-metrics true
									spark.ui.prometheus.enabled true
									spark.sql.streaming.metricsEnabled true
									spark.metrics.appStatusSource.enabled true
									spark.metrics.conf.*.sink.prometheusServlet.class=org.apache.spark.metrics.sink.PrometheusServlet
									spark.metrics.conf.*.sink.prometheusServlet.path=/metrics/prometheus
									spark.metrics.conf.master.sink.prometheusServlet.path=/metrics/master/prometheus
									spark.metrics.conf.applications.sink.prometheusServlet.path=/metrics/applications/prometheus
									\(strings.Join([for k, v in parameter.spark.sparkDefaults{"\(k) \(v)"}], "\n"))
									\(_sparkDataLocalityConf)
									"""

									"hive-log4j2.properties": """
									status = INFO
									name = HiveLog4j2
									packages = org.apache.hadoop.hive.ql.log

									# list of properties
									property.hive.log.level = INFO
									property.hive.root.logger = DRFA
									property.hive.log.dir = ${sys:java.io.tmpdir}/${sys:user.name}/__HOSTNAME__
									property.hive.log.file = hive.log
									property.hive.perflogger.log.level = INFO

									# list of all appenders
									appenders = console, DRFA

									# console appender
									appender.console.type = Console
									appender.console.name = console
									appender.console.target = SYSTEM_OUT
									appender.console.layout.type = PatternLayout
									appender.console.layout.pattern = %d{ISO8601} %5p [%t] %c{2}: %m%n

									# daily rolling file appender
									appender.DRFA.type = RollingRandomAccessFile
									appender.DRFA.name = DRFA
									appender.DRFA.fileName = ${sys:hive.log.dir}/${sys:hive.log.file}
									# Use %pid in the filePattern to append <process-id>@<host-name> to the filename if you want separate log files for different CLI session
									appender.DRFA.filePattern = ${sys:hive.log.dir}/${sys:hive.log.file}.%d{yyyy-MM-dd}
									appender.DRFA.layout.type = PatternLayout
									appender.DRFA.layout.pattern = %d{ISO8601} %5p [%t] %c{2}: %m%n
									appender.DRFA.policies.type = Policies
									appender.DRFA.policies.time.type = TimeBasedTriggeringPolicy
									appender.DRFA.policies.time.interval = 1
									appender.DRFA.policies.time.modulate = true
									appender.DRFA.strategy.type = DefaultRolloverStrategy
									appender.DRFA.strategy.max = 3

									# list of all loggers
									loggers = NIOServerCnxn, ClientCnxnSocketNIO, DataNucleus, Datastore, JPOX, PerfLogger, TThreadPoolServer

									logger.NIOServerCnxn.name = org.apache.zookeeper.server.NIOServerCnxn
									logger.NIOServerCnxn.level = WARN

									logger.ClientCnxnSocketNIO.name = org.apache.zookeeper.ClientCnxnSocketNIO
									logger.ClientCnxnSocketNIO.level = WARN

									logger.DataNucleus.name = DataNucleus
									logger.DataNucleus.level = ERROR

									logger.Datastore.name = Datastore
									logger.Datastore.level = ERROR

									logger.JPOX.name = JPOX
									logger.JPOX.level = ERROR

									logger.PerfLogger.name = org.apache.hadoop.hive.ql.log.PerfLogger
									logger.PerfLogger.level = ${sys:hive.perflogger.log.level}

									logger.TThreadPoolServer.name = org.apache.thrift.server.TThreadPoolServer
									logger.TThreadPoolServer.level = OFF

									# root logger
									rootLogger.level = ${sys:hive.log.level}
									rootLogger.appenderRefs = root
									rootLogger.appenderRef.root.ref = ${sys:hive.root.logger}
									"""

									"executorPodTemplate.yaml": """
									apiversion: v1
									kind: Pod
									spec:
									  affinity:
									    podAffinity:
									      preferredDuringSchedulingIgnoredDuringExecution:
									      - weight: 1
									        podAffinityTerm:
									          labelSelector:
									            matchExpressions:
									            - key: app
									              operator: In
									              values:
									              - hdfs-datanode
									          topologyKey: kubernetes.io/hostname
									"""
								}
							},
							{
								apiVersion: "v1"
								kind:       "ConfigMap"
								metadata: {
									namespace: context.namespace
									name:      "hive-server2-grafana-dashboard"
									labels: {
										"app":               "grafana"
										"grafana_dashboard": "1"
									}
								}
								data: {
									"hive-server2-dashboard.json": "{\"annotations\":{\"list\":[{\"builtIn\":1,\"datasource\":{\"type\":\"datasource\",\"uid\":\"grafana\"},\"enable\":true,\"hide\":true,\"iconColor\":\"rgba(0, 211, 255, 1)\",\"name\":\"Annotations & Alerts\",\"target\":{\"limit\":100,\"matchAny\":false,\"tags\":[],\"type\":\"dashboard\"},\"type\":\"dashboard\"}]},\"editable\":true,\"fiscalYearStartMonth\":0,\"graphTooltip\":0,\"id\":132,\"links\":[],\"liveNow\":false,\"panels\":[{\"collapsed\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":0},\"id\":116,\"panels\":[],\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"refId\":\"A\"}],\"title\":\"hs2 info\",\"type\":\"row\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"description\":\"Open Connections\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"color\":\"#508642\",\"text\":\"0\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"#508642\",\"value\":null},{\"color\":\"#ef843c\",\"value\":1},{\"color\":\"#bf1b00\",\"value\":5}]},\"unit\":\"none\"},\"overrides\":[]},\"gridPos\":{\"h\":8,\"w\":4,\"x\":0,\"y\":1},\"id\":102,\"links\":[],\"maxDataPoints\":100,\"options\":{\"orientation\":\"auto\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"showThresholdLabels\":false,\"showThresholdMarkers\":true},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hive_open_connections{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"})\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"open_connection\",\"range\":true,\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"sum(hive_cumulative_connection_count{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"})\",\"hide\":false,\"interval\":\"\",\"legendFormat\":\"total_connection\",\"range\":true,\"refId\":\"B\"}],\"title\":\"Open Connections\",\"type\":\"gauge\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Number of brokers online\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"#d44a3a\",\"value\":null},{\"color\":\"rgba(237, 129, 40, 0.89)\",\"value\":0},{\"color\":\"#299c46\",\"value\":2}]},\"unit\":\"none\"},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":5,\"x\":4,\"y\":1},\"id\":46,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"repeatDirection\":\"h\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"exemplar\":true,\"expr\":\"count(hive_memory_heap_used{namespace=\\\"$namespace\\\"})\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"\",\"refId\":\"A\"}],\"title\":\"Hs2 instances\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"open session\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]}},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":5,\"x\":9,\"y\":1},\"id\":187,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"repeatDirection\":\"h\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hive_hs2_open_sessions{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"})\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"active_sessions\",\"range\":true,\"refId\":\"A\"}],\"title\":\"open session\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"active session\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]}},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":5,\"x\":14,\"y\":1},\"id\":136,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"repeatDirection\":\"h\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hive_hs2_active_sessions{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"})\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"active_sessions\",\"range\":true,\"refId\":\"A\"}],\"title\":\"active session\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"authorization\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"index\":0,\"text\":\"0\"}},\"type\":\"special\"}],\"noValue\":\"0\",\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"#508642\",\"value\":null}]},\"unit\":\"none\"},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":5,\"x\":19,\"y\":1},\"id\":128,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"max\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum (hive_api_doauthorization{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}) by (pod) >= 0\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"doauthorization\",\"range\":true,\"refId\":\"A\"}],\"title\":\"authorization\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Submitted Queries\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[],\"noValue\":\"0\",\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]}},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":4,\"x\":4,\"y\":5},\"id\":137,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"repeatDirection\":\"h\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hive_hs2_submitted_queries{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"})\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"submitted_queries\",\"range\":true,\"refId\":\"A\"}],\"title\":\"Submitted Queries\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"failed Queries\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[],\"noValue\":\"0\",\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]}},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":4,\"x\":8,\"y\":5},\"id\":140,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"repeatDirection\":\"h\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hive_hs2_failed_queries{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"})\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"failed Queries\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"succeeded Queries\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[],\"noValue\":\"0\",\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]}},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":4,\"x\":12,\"y\":5},\"id\":141,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"repeatDirection\":\"h\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hive_hs2_succeeded_queries{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"})\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"succeeded_queries\",\"range\":true,\"refId\":\"A\"}],\"title\":\"succeeded Queries\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"total tasks\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[],\"noValue\":\"0\",\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]}},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":4,\"x\":16,\"y\":5},\"id\":188,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"repeatDirection\":\"h\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hive_api_runtasks{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"})\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"tasks\",\"range\":true,\"refId\":\"A\"}],\"title\":\"total tasks\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"spark tasks\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[],\"noValue\":\"0\",\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]}},\"overrides\":[]},\"gridPos\":{\"h\":4,\"w\":4,\"x\":20,\"y\":5},\"id\":186,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"repeatDirection\":\"h\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hive_spark_tasks{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"})\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"spark_tasks\",\"range\":true,\"refId\":\"A\"}],\"title\":\"spark tasks\",\"type\":\"stat\"},{\"collapsed\":false,\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":9},\"id\":144,\"panels\":[],\"title\":\"session info\",\"type\":\"row\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"description\":\"open session\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":0,\"y\":10},\"hiddenSeries\":false,\"id\":145,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hive_hs2_open_sessions{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"open session\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1452\",\"decimals\":0,\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1453\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"description\":\"active session\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":12,\"y\":10},\"hiddenSeries\":false,\"id\":146,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum (hive_hs2_active_sessions{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"active session\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1452\",\"decimals\":0,\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1453\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"description\":\"avg open session time\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":0,\"y\":17},\"hiddenSeries\":false,\"id\":147,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum (hive_hs2_avg_open_session_time{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"avg open session time\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1452\",\"decimals\":0,\"format\":\"ms\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1453\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"description\":\"avg active session time\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":12,\"y\":17},\"hiddenSeries\":false,\"id\":148,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hive_hs2_avg_active_session_time{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"avg active session time\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1452\",\"decimals\":0,\"format\":\"ms\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1453\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"collapsed\":false,\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":24},\"id\":150,\"panels\":[],\"title\":\"Queries\",\"type\":\"row\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"description\":\"submmited queries\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":8,\"x\":0,\"y\":25},\"hiddenSeries\":false,\"id\":151,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum (hive_hs2_submitted_queries{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"submmited queries\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1452\",\"decimals\":0,\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1453\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"description\":\"succeeded queries\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":8,\"x\":8,\"y\":25},\"hiddenSeries\":false,\"id\":152,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hive_hs2_succeeded_queries{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"succeeded queries\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1452\",\"decimals\":0,\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1453\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"description\":\"failed queries\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":8,\"x\":16,\"y\":25},\"hiddenSeries\":false,\"id\":153,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hive_hs2_failed_queries{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"failed queries\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1452\",\"decimals\":0,\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1453\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"collapsed\":false,\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":32},\"id\":155,\"panels\":[],\"title\":\"Task\",\"type\":\"row\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"description\":\"total tasks\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":8,\"x\":0,\"y\":33},\"hiddenSeries\":false,\"id\":156,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hive_api_runtasks{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"total tasks\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1452\",\"decimals\":0,\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1453\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"description\":\"spark tasks\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":8,\"x\":8,\"y\":33},\"hiddenSeries\":false,\"id\":157,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hive_spark_tasks{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"spark tasks\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1452\",\"decimals\":0,\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1453\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"description\":\"active runtasks\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":8,\"x\":16,\"y\":33},\"hiddenSeries\":false,\"id\":158,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hive_active_calls_api_runtasks{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"active runtasks\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1452\",\"decimals\":0,\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1453\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"collapsed\":false,\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":40},\"id\":160,\"panels\":[],\"title\":\"Spark job\",\"type\":\"row\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"description\":\"submit job\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"decimals\":0,\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"none\"},\"overrides\":[]},\"gridPos\":{\"h\":7,\"w\":12,\"x\":0,\"y\":41},\"id\":161,\"links\":[],\"options\":{\"legend\":{\"calcs\":[\"lastNotNull\",\"max\",\"min\"],\"displayMode\":\"table\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hive_api_sparksubmitjob{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\"submit job\",\"type\":\"timeseries\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"description\":\"acitve submit job\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":12,\"y\":41},\"hiddenSeries\":false,\"id\":162,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hive_active_calls_api_sparksubmitjob{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"acitve submit job\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1452\",\"decimals\":0,\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1453\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"description\":\"run job\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":0,\"y\":48},\"hiddenSeries\":false,\"id\":163,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hive_api_sparkrunjob{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"run job\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1452\",\"decimals\":0,\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1453\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"description\":\"acitve run job\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":12,\"y\":48},\"hiddenSeries\":false,\"id\":164,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hive_active_calls_api_sparkrunjob{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"acitve run job\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1452\",\"decimals\":0,\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1453\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"collapsed\":false,\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":55},\"id\":168,\"panels\":[],\"title\":\"partition retrieving\",\"type\":\"row\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"description\":\"partition_retrieving\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":0,\"y\":56},\"hiddenSeries\":false,\"id\":169,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hive_api_partition_retrieving{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"partition_retrieving\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1452\",\"decimals\":0,\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1453\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"description\":\"acitve partition retrieving\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":12,\"y\":56},\"hiddenSeries\":false,\"id\":170,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hive_active_calls_api_partition_retrieving{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"acitve partition retrieving\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1452\",\"decimals\":0,\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1453\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"collapsed\":false,\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":63},\"id\":172,\"panels\":[],\"title\":\"container resource info\",\"type\":\"row\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Memory Usage\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":8,\"x\":0,\"y\":64},\"hiddenSeries\":false,\"id\":173,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"max (container_memory_usage_bytes{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Memory Usage\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:692\",\"format\":\"bytes\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:693\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"CPU Usage\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":8,\"x\":8,\"y\":64},\"hiddenSeries\":false,\"id\":174,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(rate(container_cpu_usage_seconds_total{container=\\\"hive-server2\\\", namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}[5m])) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"CPU Usage\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:692\",\"format\":\"short\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:693\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Disk Usage\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":8,\"x\":16,\"y\":64},\"hiddenSeries\":false,\"id\":175,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"expr\":\"max (container_fs_reads_bytes_total{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"hide\":false,\"legendFormat\":\"{{pod}}-read\",\"range\":true,\"refId\":\"B\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"max (container_fs_writes_bytes_total{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}-write\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Disk Usage\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:692\",\"format\":\"bytes\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:693\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"collapsed\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":71},\"id\":28,\"panels\":[],\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"refId\":\"A\"}],\"title\":\"JVM\",\"type\":\"row\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":6,\"w\":12,\"x\":0,\"y\":72},\"hiddenSeries\":false,\"id\":93,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(jvm_memory_bytes_used{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"JVM Memory Used\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:2038\",\"format\":\"decbytes\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:2039\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"JVM Class loaded\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":6,\"w\":12,\"x\":12,\"y\":72},\"hiddenSeries\":false,\"id\":176,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(hive_classloading_loaded{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"JVM Class loaded\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:2038\",\"format\":\"decbytes\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:2039\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Heap Memory Used\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":6,\"w\":12,\"x\":0,\"y\":78},\"hiddenSeries\":false,\"id\":177,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(hive_memory_heap_used{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Heap Memory Used\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:2038\",\"format\":\"decbytes\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:2039\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"NonHeap Memory Used\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":6,\"w\":12,\"x\":12,\"y\":78},\"hiddenSeries\":false,\"id\":178,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(hive_memory_non_heap_used{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"NonHeap Memory Used\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:2038\",\"format\":\"decbytes\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:2039\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"JVM thread count\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":6,\"w\":6,\"x\":0,\"y\":84},\"hiddenSeries\":false,\"id\":108,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum (jvm_threads_current{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"JVM Thread Count\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:476\",\"format\":\"short\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:477\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"description\":\"JVM thread deadlock\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":6,\"w\":6,\"x\":6,\"y\":84},\"hiddenSeries\":false,\"id\":130,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"sum(hive_threads_deadlock_count{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"hide\":false,\"interval\":\"\",\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"G\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"JVM thread deadlock\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1288\",\"format\":\"short\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1289\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"description\":\"JVM thread blocked\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":6,\"w\":6,\"x\":12,\"y\":84},\"hiddenSeries\":false,\"id\":180,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hive_threads_blocked_count{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"hide\":false,\"interval\":\"\",\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"H\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"JVM thread blocked\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1288\",\"format\":\"short\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1289\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"description\":\"Thread status\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":6,\"w\":6,\"x\":18,\"y\":84},\"hiddenSeries\":false,\"id\":179,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hive_threads_new_count{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}-create\",\"range\":true,\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"hive_threads_daemon_count{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}\",\"hide\":false,\"interval\":\"\",\"legendFormat\":\"{{pod}}-daemon\",\"range\":true,\"refId\":\"B\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"hive_threads_timed_waiting_count{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}\",\"hide\":false,\"interval\":\"\",\"legendFormat\":\"{{pod}}-timed-waiting\",\"range\":true,\"refId\":\"C\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"hive_threads_terminated_count{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}\",\"hide\":false,\"interval\":\"\",\"legendFormat\":\"{{pod}}-terminated\",\"range\":true,\"refId\":\"D\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"hive_threads_runnable_count{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}\",\"hide\":false,\"interval\":\"\",\"legendFormat\":\"{{pod}}-runnable\",\"range\":true,\"refId\":\"E\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"hive_threads_waiting_count{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}\",\"hide\":false,\"interval\":\"\",\"legendFormat\":\"{{pod}}-waiting\",\"range\":true,\"refId\":\"F\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Thread status\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:1288\",\"format\":\"short\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:1289\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":6,\"w\":12,\"x\":0,\"y\":90},\"hiddenSeries\":false,\"id\":182,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(increase(jvm_gc_collection_seconds_count{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"}[1m])) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"JVM GC Count\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:2705\",\"format\":\"short\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:2706\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":6,\"w\":12,\"x\":12,\"y\":90},\"hiddenSeries\":false,\"id\":181,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(increase(jvm_gc_collection_seconds_sum{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\"}[1m])) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"JVM GC Time\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:2705\",\"format\":\"ms\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:2706\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":6,\"w\":6,\"x\":0,\"y\":96},\"hiddenSeries\":false,\"id\":97,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(increase(jvm_gc_collection_seconds_count{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\",gc=~\\\"Copy|G1 Young Generation\\\"}[1m])) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Young GC Count\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:2705\",\"format\":\"short\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:2706\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":6,\"w\":6,\"x\":6,\"y\":96},\"hiddenSeries\":false,\"id\":183,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(increase(jvm_gc_collection_seconds_count{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\",gc=~\\\"MarkSweepCompact|G1 Old.*\\\"}[1m])) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Old GC Count\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:2705\",\"format\":\"short\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:2706\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":6,\"w\":6,\"x\":12,\"y\":96},\"hiddenSeries\":false,\"id\":184,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(increase(jvm_gc_collection_seconds_sum{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\",gc=~\\\"Copy|G1 Young Generation\\\"}[1m])) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Young GC Time\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:2705\",\"format\":\"ms\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:2706\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":6,\"w\":6,\"x\":18,\"y\":96},\"hiddenSeries\":false,\"id\":185,\"legend\":{\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"$datasource\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(increase(jvm_gc_collection_seconds_sum{namespace=\\\"$namespace\\\",container=\\\"hive-server2\\\",pod=~\\\"$pod\\\",gc=~\\\"MarkSweepCompact|G1 Old Generation\\\"}[1m])) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Old GC Time\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:2705\",\"format\":\"ms\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:2706\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}}],\"refresh\":\"30m\",\"schemaVersion\":36,\"style\":\"dark\",\"tags\":[\"hive\",\"hs2\"],\"templating\":{\"list\":[{\"current\":{\"selected\":false,\"text\":\"Prometheus\",\"value\":\"Prometheus\"},\"hide\":0,\"includeAll\":false,\"label\":\"datasource\",\"multi\":false,\"name\":\"datasource\",\"options\":[],\"query\":\"prometheus\",\"queryValue\":\"\",\"refresh\":1,\"regex\":\"\",\"skipUrlSync\":false,\"type\":\"datasource\"},{\"current\":{\"selected\":false,\"text\":\"admin\",\"value\":\"admin\"},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"definition\":\"query_result(hive_memory_heap_used)\",\"hide\":0,\"includeAll\":false,\"label\":\"Namespace\",\"multi\":false,\"name\":\"namespace\",\"options\":[],\"query\":{\"query\":\"query_result(hive_memory_heap_used)\",\"refId\":\"StandardVariableQuery\"},\"refresh\":1,\"regex\":\"/.*namespace=\\\"([^\\\"]+).*/\",\"skipUrlSync\":false,\"sort\":1,\"tagValuesQuery\":\"\",\"tagsQuery\":\"\",\"type\":\"query\",\"useTags\":false},{\"allValue\":\".*\",\"current\":{\"selected\":true,\"text\":[\"hive-server2-0\"],\"value\":[\"hive-server2-0\"]},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"definition\":\"query_result(count_over_time(hive_memory_heap_used{namespace=\\\"$namespace\\\"}[$__range]))\",\"hide\":0,\"includeAll\":true,\"label\":\"Pod\",\"multi\":true,\"name\":\"pod\",\"options\":[],\"query\":{\"query\":\"query_result(count_over_time(hive_memory_heap_used{namespace=\\\"$namespace\\\"}[$__range]))\",\"refId\":\"StandardVariableQuery\"},\"refresh\":2,\"regex\":\"/.*pod=\\\"([^\\\"]+).*/\",\"skipUrlSync\":false,\"sort\":1,\"tagValuesQuery\":\"\",\"tagsQuery\":\"\",\"type\":\"query\",\"useTags\":false}]},\"time\":{\"from\":\"now-5m\",\"to\":\"now\"},\"timepicker\":{\"refresh_intervals\":[\"5s\",\"10s\",\"30s\",\"1m\",\"5m\",\"15m\",\"30m\",\"1h\",\"2h\",\"1d\"],\"time_options\":[\"5m\",\"15m\",\"1h\",\"6h\",\"12h\",\"24h\",\"2d\",\"7d\",\"30d\"]},\"timezone\":\"\",\"title\":\"hive-server2\",\"uid\":\"t5_CsYCnz\",\"version\":2,\"weekStart\":\"\"}\n"
								}
							},
							{
								apiVersion: "bdc.kdp.io/v1alpha1"
								kind: "ContextSetting"
								metadata: {
									name: "\(context.bdc)-\(context.name)"
									annotations: {
										"setting.ctx.bdc.kdp.io/type": "Hive"
										"setting.ctx.bdc.kdp.io/origin": "system"
									}
								},
								spec: {
									name: context.name + "-context"
									type: "hive-server2"
									properties: {
										_commonConf: {
											"hive.zookeeper.quorum": parameter.dependencies.zookeeperQuorum
											"hive.server2.thrift.bind.host": "\(context.name)-0.\(context.name).\(context.namespace).svc.cluster.local"
										}
										_commonConfStr: "\n\t\(strings.Join([for k, v in _commonConf {"<property>\n\t\t<name>\(k)</name>\n\t\t<value>\(v)</value>\n\t</property>"}], "\n\t"))"
										
										"hiveSite": """
										<?xml version="1.0"?>
										<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
										<configuration>
											\(strings.Join([for k, v in parameter.hiveConf{"<property>\n\t\t<name>\(k)</name>\n\t\t<value>\(v)</value>\n\t</property>"}], "\n\t") + _commonConfStr)
										</configuration>
										"""

										"host": "\(context.name)-0.\(context.name).\(context.namespace).svc.cluster.local"
										"port": "10000"
										"url": "jdbc:hive2//\(context.name)-0.\(context.name).\(context.namespace).svc.cluster.local:10000"
										"zkNode": "\(context.namespace)_hiveserver2/server"
									}
								}
							},
							{
								apiVersion: "v1"
								kind: "Service"
								metadata: {
									name: context.name
									labels: {
										app: context.name
									}
								}
								spec: {
									ports: [{
											name: "hive-server2"
											port: 10000
											targetPort: 10000
										}, {
											name: "http"
											port: 10001
											targetPort: 10001
										}, {
											name: "webui"
											port: 10002
											targetPort: 10002
										}, {
											name: "prometheus-port"
											port: 9008
											targetPort: 9008
										}]
									clusterIP: "None"
									selector: {
										app: context.name
									}
								}
							}
						]
					}
					"traits": [
						{
							"type": "bdos-service-account"
							"properties": {
								"name": context.name
							}
						},
						{
							"type": "bdos-service-account"
							"properties": {
								"name": "hive-spark"
							}
						},
						{
							"type": "bdos-pod-affinity"
							"properties": {
								"antiAffinity": {
									"app": [
										context.name,
									]
								}
								"topologyKey": "kubernetes.io/hostname"
							}
						},
						{
							"type": "bdos-monitor"
							"properties": {
								"endpoints": [
									{
										"port":     9008
										"portName": "prometheus-port"
									},
								]
								"matchLabels": {
									"app": context.name
								}
							}
						},
						{
							"type": "bdos-logtail"
							"properties": {
								"name":         "logs"
								"path":         "/var/log/\(context.namespace)-\(context.name)"
								"subdirectory": ".**"
								"promtail": {
									"memory": "128Mi"
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
												"alert":    "\(context.namespace)_\(context.name)_high_memory_usage"
												"expr":     "sum(container_memory_usage_bytes{namespace=\"\(context.namespace)\",container=\"hive-server2\"}) by (namespace,pod)/sum(cluster:namespace:pod_memory:active:kube_pod_container_resource_limits{namespace=\"\(context.namespace)\",container=\"hive-server2\"}) by (namespace,pod)  > 0.9"
												"duration": "300s"
												"labels": {
													"severity": "medium"
													"channel":  "grafana_oncall"
												}
												"annotations": {
													"summary":     "The pod {{ $labels.pod }} in namespace {{ $labels.namespace }} high memory usage"
													"description": "The pod {{ $labels.pod }} in namespace {{ $labels.namespace }} memory used more than 90%,value is {{ $value }}"
												}
											},
											{
												"alert":    "\(context.namespace)_\(context.name)_queries_failed"
												"expr":     "sum(increase(hive_hs2_failed_queries{namespace=\"\(context.namespace)\",container=\"hive-server2\"}[3m])) by (namespace,pod) > 5"
												"duration": "3m"
												"labels": {
													"severity": "warning"
													"channel":  "grafana_oncall"
												}
												"annotations": {
													"summary":     "The pod {{ $labels.pod }} in namespace {{ $labels.namespace }} too much queries failed."
													"description": "Found failure queries: {{ $value }}."
												}
											},
											{
												"alert": "\(context.namespace)_\(context.name)_active_sessions too many connections"
												"annotations": {
													"description": "{{$labels.namespace}} hive_hs2_active_sessions in 2 minute  is {{ $value }}"
													"summary":     "{{$labels.namespace}} hive_hs2_active_sessions "
												}
												"expr":     "hive_hs2_active_sessions > 30"
												"duration": "2m"
												"labels": {
													"severity": "warning"
													"channel":  "grafana_oncall"
												}
											},
											{
												"alert": "\(context.namespace)_\(context.name)_hs2_open_connections too many connections"
												"annotations": {
													"description": "{{$labels.namespace}} hive_hs2_open_sessions in 2 minute  is {{ $value }}"
													"summary":     "{{$labels.namespace}} hive_hs2_open_sessions too many connections "
												}
												"expr":     "hive_hs2_open_sessions > 1000"
												"duration": "2m"
												"labels": {
													"severity": "warning"
													"channel":  "grafana_oncall"
												}
											},
											{
												"alert": "\(context.namespace)_\(context.name)_hive_active_calls_api_hs2_operation_pending too many in 2m"
												"annotations": {
													"description": "{{$labels.namespace}} hive_active_calls_api_hs2_operation_pending in 2 minute  is {{ $value }}"
													"summary":     "{{$labels.namespace}} hive_active_calls_api_hs2_operation_pending too many connections "
												}
												"expr":     "increase(hive_active_calls_api_hs2_operation_pending[2m]) > 5"
												"duration": "2m"
												"labels": {
													"severity": "warning"
													"channel":  "grafana_oncall"
												}
											},
											{
												"alert": "\(context.namespace)_\(context.name)_hive_active_calls_api_hs2_sql_operation_pending too many in 2m"
												"annotations": {
													"description": "{{$labels.namespace}} hive_active_calls_api_hs2_sql_operation_pending in 2 minute  is {{ $value }}"
													"summary":     "{{$labels.namespace}} hive_active_calls_api_hs2_sql_operation_pending too many connections "
												}
												"expr":     "increase(hive_active_calls_api_hs2_sql_operation_pending[2m]) > 5"
												"duration": "2m"
												"labels": {
													"severity": "warning"
													"channel":  "grafana_oncall"
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
					"name": "\(context.name)-\(context.namespace)-role"
					"type": "bdos-role"
					"properties": {
						"rules": [
							{
								"apiGroups": [
									"*",
								]
								"resources": [
									"pods",
									"pods/log",
									"configmaps",
									"secrets",
									"services",
									"statefulsets",
									"events",
								]
								"verbs": [
									"get",
									"watch",
									"list",
									"create",
									"update",
									"patch",
									"delete",
								]
							},
							{
								"apiGroups": [
									"*",
								]
								"resources": [
									"nodes",
								]
								"verbs": [
									"get",
									"list",
								]
							},
						]
					}
				},
				{
					"name": "\(context.name)-\(context.namespace)-role-binding"
					"type": "bdos-role-binding"
					"properties": {
						"roleName": "\(context.name)-\(context.namespace)-role"
						"serviceAccounts": [
							{
								"serviceAccountName": context.name
								"namespace":          context.namespace
							},
						]
					}
				},
				{
					"name": "hive-spark-\(context.namespace)-role"
					"type": "bdos-role"
					"properties": {
						"rules": [
							{
								"apiGroups": [
									"*",
								]
								"resources": [
									"pods",
									"configmaps",
									"secrets",
									"services",
								]
								"verbs": [
									"get",
									"watch",
									"list",
									"create",
									"update",
									"patch",
									"delete",
								]
							},
							{
								"apiGroups": [
									"*",
								]
								"resources": [
									"persistentvolumeclaims",
								]
								"verbs": [
									"get",
									"list",
									"create",
									"delete",
								]
							},
						]
					}
				},
				{
					"name": "hive-spark-\(context.namespace)-role-binding"
					"type": "bdos-role-binding"
					"properties": {
						"roleName": "hive-spark-\(context.namespace)-role"
						"serviceAccounts": [
							{
								"serviceAccountName": "hive-spark"
								"namespace":          context.namespace
							},
						]
					}
				},
				{
					"name": "hive-spark-\(context.namespace)-cluster-role"
					"type": "bdos-cluster-role"
					"properties": {
						"rules": [
							{
								"apiGroups": [
									"*",
								]
								"resources": [
									"pods",
								]
								"verbs": [
									"list",
								]
							},
							{
								"apiGroups": [
									"*",
								]
								"resources": [
									"nodes",
								]
								"verbs": [
									"get",
									"list",
								]
							},
						]
					}
				},
				{
					"name": "hive-spark-\(context.namespace)-cluster-role-binding"
					"type": "bdos-cluster-role-binding"
					"properties": {
						"clusterRoleRefName": "hive-spark-\(context.namespace)-cluster-role"
						"serviceAccounts": [
							{
								"serviceAccountName": "hive-spark"
								"namespace":          context.namespace
							},
						]
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
									"componentNames": [
										"hive-server2-grafana-dashboard",
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
			// +ui:description=HDFS 上下文
			// +ui:order=2
			// +err:options={"required":"请先安装 HDFS"}
			hdfsConfigMapName: string
			// +ui:description=Hive Metastore 上下文
			// +ui:order=3
			// +err:options={"required":"请先安装 Hive Metastore"}
			hmsConfigMapName: string
		}
		// +ui:description=副本数
		// +ui:order=2
		// +minimum=1
		replicas: *1 | int
		// +ui:description=资源规格
		// +ui:order=3
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
		// +ui:description=Spark pod 尽量调度到数据节点
		// +ui:order=4
		dataLocality: *true | bool
		// +ui:description=自定义 hive-site.xml 内容
		// +ui:order=5
		hiveConf: *{
			"hive.execution.engine":                                   "spark"
			"hive.zookeeper.kerberos.enabled":                         "false"
			"hive.scratch.dir.permission":                             "733"
			"hive.spark.client.rpc.server.port":                       "10010-10020"
			"hive.security.authorization.sqlstd.confwhitelist.append": #"mapreduce\.job\..*|dfs\..*|hive\.zookeeper\..*|fs\.s3a\..*|spark\..*|hive\.exec\.scratchdir|hive\.metastore\.warehouse\.dir|hive\.query\.results\.cache\.directory"#
			"hive.server2.metrics.enabled":                            "true"
			"hive.server2.support.dynamic.service.discovery":          "true"
			"hive.exec.local.scratchdir":                              "/tmp/hive"
			"hive.metastore.warehouse.dir":                            "/user/hive/warehouse"
			"hive.materializedview.rewriting":                         "false"
			"hive.server2.session.check.interval":                     "15m"
			"hive.server2.idle.session.timeout":                       "4h"
			"hive.server2.idle.operation.timeout":                     "2h"
			"hive.server2.authentication":                             "NOSASL"
		} | {...}
		// +ui:description=Spark 配置
		// +ui:order=6
		spark: {
			// +ui:description=Spark 镜像版本
			// +ui:order=1
			// +ui:options={"disabled":true}
			image: string
			// +ui:description=自定义 spark-defaults.conf 内容
			// +ui:order=3
			sparkDefaults: *{
				"spark.kryoserializer.buffer.max": "128m"
				"spark.eventLog.enabled":          "true"
			} | {...}
		}
		// +ui:description=镜像版本
		// +ui:order=100
		// +ui:options={"disabled":true}
		image: string
	}
}
