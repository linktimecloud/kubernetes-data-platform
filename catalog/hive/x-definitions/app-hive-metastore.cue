import ("strings")
import ("strconv")

"hive-metastore": {
  annotations: {}
  labels: {}
  attributes: {
    "dynamicParameterMeta": [
      {
        "name": "dependencies.hdfsConfigMapName",
        "type": "ContextSetting",
        "refType": "hdfs",
        "refKey": "",
        "description": "hdfs config name",
        "required": true
      },
      {
        "name": "dependencies.mysql.configName",
        "type": "ContextSetting",
        "refType": "mysql",
        "refKey": "",
        "description": "mysql config",
        "required": true
      },
      {
        "name": "dependencies.mysql.secretName",
        "type": "ContextSecret",
        "refType": "mysql",
        "refKey": "",
        "description": "mysql secret",
        "required": true
      }
		]
		apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "Application"
				type: "hive-metastore"
			}
		}
  }
  description: "hive-metastore xdefinition"
  type: "xdefinition"
}

template: {
  output: {
    "apiVersion": "core.oam.dev/v1beta1",
    "kind": "Application",
    "metadata": {
      "name": context.name,
      "namespace": context.namespace,
      "labels": {
        "app": context.name,
        "app.core.bdos/type": "system"
      }
    },
    "spec": {
      "components": [
        {
          "name": context.name,
          "type": "k8s-objects",
          "properties": {
            "objects": [
              {
                apiVersion: "apps/v1"
                kind:       "Deployment"
                metadata: {
                  name: context.name
                  annotations: {
                    "app.core.bdos/catalog":        "hive"
                    "reloader.stakater.com/auto": "true"
                  }
                  labels: {
                    app:                        context.name
                    "app.core.bdos/type":       "system"
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
                    metadata: labels: {
                      app:                     context.name
                      "app.oam.dev/component": context.name
                    }
                    spec: {
                      containers: [{
                        name: context.name
                        env: [{
                          name: "HIVE_CONNECTION_USER_NAME"
                          valueFrom: secretKeyRef: {
                            name: "\(parameter.dependencies.mysql.secretName)"
                            key: "MYSQL_USER"
                          }
                        }, {
                          name:  "IMPORT_DB_HOST"
                          valueFrom: configMapKeyRef: {
                            name: "\(parameter.dependencies.mysql.configName)"
                            key: "MYSQL_HOST"
                          }
                        }, {
                          name:  "IMPORT_DB_PORT"
                          valueFrom: configMapKeyRef: {
                            name: "\(parameter.dependencies.mysql.configName)"
                            key: "MYSQL_PORT"
                          }
                        }, {
                          name:  "IMPORT_DB_DATABASE"
                          value: "\(strings.Replace("\(context.bdc)_hive_db", "-", "_", -1))"
                        }, {
                          name: "HIVE_PASSWORD"
                          valueFrom: secretKeyRef: {
                              name: "\(parameter.dependencies.mysql.secretName)"
                              key: "MYSQL_PASSWORD"
                          }
                        }, {
                          name:  "USER_SERVICE"
                          value: "bdos-user-service-svc.admin.svc.cluster.local:4100"
                        }, {
                          name:  "STORAGE_MULTI_TENANCY_ENABLE"
                          value: "\(strconv.FormatBool(parameter.multiTenancy))"
                        }]
                        
                        image: "\(context.docker_registry)/\(parameter.image)"
                        command: ["/hms/sbin/run.sh"]
                        livenessProbe: {
                          initialDelaySeconds: 20
                          periodSeconds: 20
                          failureThreshold: 3
                          timeoutSeconds: 10
                          tcpSocket: {
                            port: 9083
                          }
                        }
                        readinessProbe: {
                          exec: {
                            command: ["bash", "/hms/sbin/healthcheck.sh"]
                          }
                          initialDelaySeconds: 10
                          periodSeconds: 20
                          timeoutSeconds: 10
                          failureThreshold: 3
                        }
                        resources: parameter.resources

                        volumeMounts: [{
                          name:      "logs"
                          mountPath: "/tmp/root"
                        }, {
                          name: "hdfs-conf"
                          mountPath: "/opt/hadoop/etc/hadoop"
                          readOnly: true
                        }, {
                          name: "hive-server-conf"
                          mountPath: "/tmp/conf"
                          readOnly: true
                        }, {
                          name: "hms-scripts"
                          mountPath: "/hms/sbin/"
                          readOnly: true
                        }, 
                        ]
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
                        name: "hms-scripts"
                        configMap: {
                          name: context.name + "-scripts"
                          defaultMode: 484
                        }
                      },
                      ]
                    }
                  }
                }
              },
              {
                apiVersion: "v1"
                kind: "Service"
                metadata: {
                  name: context.name + "-svc"
                  labels: {
                    "app": context.name
                  }
                }
                spec: {
                  selector: {
                    "app": context.name
                  }
                  ports: [
                    {
                      name: "port-tcp-9083"
                      protocol: "TCP"
                      port: 9083
                      targetPort: 9083
                    },
                    {
                      name: "port-tcp-7979"
                      protocol: "TCP"
                      port: 7979
                      targetPort: 7979
                    },
                    {
                      name: "port-tcp-8000"
                      protocol: "TCP"
                      port: 8000
                      targetPort: 8000
                    }
                  ]
                  type: "ClusterIP"
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
                  "init_db.sh": """
                  #!/usr/bin/env bash
                  set -e

                  mysql_link="mysql -u $HIVE_CONNECTION_USER_NAME -p$HIVE_PASSWORD -h $IMPORT_DB_HOST -P $IMPORT_DB_PORT"

                  databases=`echo "show databases; " | ${mysql_link}`
                  exist=`echo "$databases" | grep -wq ${IMPORT_DB_DATABASE} && echo 1 || echo 0`
                  if [ $exist -eq 1 ] ;then
                      echo "Database ${IMPORT_DB_DATABASE} exists. Set character to latin1."
                      echo "alter database ${IMPORT_DB_DATABASE} character set latin1;" | ${mysql_link}
                      value=`echo "use ${IMPORT_DB_DATABASE};show variables like'character_set_database'; " | ${mysql_link}`
                      character=`echo "$value" |grep -wq 'latin1' && echo 1 || echo 0`
                      if [ $character -eq 0 ] ;then
                        echo "failed to update ${IMPORT_DB_DATABASE} character"
                        exit 1;
                      fi
                      echo "Done"
                  else
                      echo "create database if not exists ${IMPORT_DB_DATABASE} DEFAULT character set latin1;" | ${mysql_link}
                  fi
                  """

                  "run.sh": """
                  #!/usr/bin/env bash
                  set -e

                  cp /tmp/conf/hive-site.xml /opt/hive/conf/hive-site.xml
                  cp /tmp/conf/hive-log4j2.properties /opt/hive/conf/hive-log4j2.properties
                  sed -i "s|__MYSQL_USERNAME__|${HIVE_CONNECTION_USER_NAME}|g" /opt/hive/conf/hive-site.xml
                  sed -i "s|__MYSQL_PASSWORD__|${HIVE_PASSWORD}|g" /opt/hive/conf/hive-site.xml
                  sed -i "s|__MYSQL_HOST__|${IMPORT_DB_HOST}|g" /opt/hive/conf/hive-site.xml
                  sed -i "s|__MYSQL_PORT__|${IMPORT_DB_PORT}|g" /opt/hive/conf/hive-site.xml

                  mysql_link="mysql -u $HIVE_CONNECTION_USER_NAME -p$HIVE_PASSWORD -h $IMPORT_DB_HOST -P $IMPORT_DB_PORT"

                  cd /tmp
                  nohup python -m http.server 8000 >/var/log/jmx_exporter.txt 2>&1 &

                  cd /opt/hive

                  exist_table=`echo "use ${IMPORT_DB_DATABASE};show tables;" | ${mysql_link} |grep -wqi txn_components  && echo 1 || echo 0`

                  echo "exist_table: $exist_table"

                  if [ $exist_table -eq 0 ] ;then
                      echo '---------bin/schematool -initSchema -dbType mysql ------'
                      bin/schematool -initSchema -dbType mysql

                      echo "---------update table columns------"
                      ${mysql_link}  ${IMPORT_DB_DATABASE} < /hms/upgrade.sql
                  fi

                  export HIVE_OPTIONS="${HIVE_OPTIONS:-} -Duser.name=hive"
                  mkdir -p /opt/metrics
                  cp -rf /hms/hms-json-export.yml /opt/metrics/hms-json-export.yml

                  echo "Starting the HiveMetaStore service"
                  bin/hive --service metastore
                  """

                  "healthcheck.sh": """
                  #!/usr/bin/env bash

                  ###check to see if MySQL has successfully connected
                  if [ -z $IMPORT_DB_HOST ] || [ -z $IMPORT_DB_PORT ] || [ -z $HIVE_CONNECTION_USER_NAME ] || [ -z $HIVE_PASSWORD ] || [ -z $IMPORT_DB_DATABASE ]; then
                    echo "#####WARN#####IMPORT_DB_HOST or IMPORT_DB_PORT or HIVE_CONNECTION_USER_NAME or HIVE_PASSWORD or IMPORT_DB_DATABASE needs to be set as environment addresses to be able to run."
                  fi

                  mysql -h $IMPORT_DB_HOST -u $HIVE_CONNECTION_USER_NAME -p$HIVE_PASSWORD -P $IMPORT_DB_PORT -e "use $IMPORT_DB_DATABASE;"
                  if [[ $? -ne 0 ]]; then
                      echo "#####ERRROR#####check mysql failed! Please confirm that mysql is normal."
                      exit 1
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
                  _mysqlConf: {
                    "javax.jdo.option.ConnectionDriverName": "com.mysql.jdbc.Driver"
                    "javax.jdo.option.ConnectionURL": "jdbc:mysql://__MYSQL_HOST__:__MYSQL_PORT__/\(strings.Replace("\(context.bdc)_hive_db", "-", "_", -1))?createDatabaseIfNotExist=true&amp;useUnicode=true&amp;characterEncoding=UTF-8&amp;useSSL=false"
                    "javax.jdo.option.ConnectionUserName": "__MYSQL_USERNAME__"
                    "javax.jdo.option.ConnectionPassword": "__MYSQL_PASSWORD__"
                  }
                  _mysqlConfStr: "\n\t\(strings.Join([for k, v in _mysqlConf {"<property>\n\t\t<name>\(k)</name>\n\t\t<value>\(v)</value>\n\t</property>"}], "\n\t"))"
                  "hive-site.xml": """
                  <?xml version="1.0"?>
                  <?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
                  <configuration>
                    \(strings.Join([for k, v in parameter.hiveConf{"<property>\n\t\t<name>\(k)</name>\n\t\t<value>\(v)</value>\n\t</property>"}], "\n\t") + _mysqlConfStr)
                  </configuration>
                  """

                  "hive-log4j2.properties": """
                  status = INFO
                  name = HiveLog4j2
                  packages = org.apache.hadoop.hive.ql.log

                  # list of properties
                  property.hive.log.level = INFO
                  property.hive.root.logger = DRFA
                  property.hive.log.dir = ${sys:java.io.tmpdir}/${sys:user.name}
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
                }
              },
              {
                apiVersion: "v1",
                kind: "ConfigMap",
                metadata: {
                  name: "hms-admin-cfg"
                },
                data: {
                  "hms-json-export.yml": #"""
                  metrics:
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..create_total_count_dbs}'
                      labels:
                        environment: hms # static label
                      values:
                        create_total_count_dbs: '{.count}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..create_total_count_tables}'
                      labels:
                        environment: hms # static label
                      values:
                        create_total_count_tables: '{.count}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..create_total_count_partitions}'
                      labels:
                        environment: hms # static label
                      values:
                        create_total_count_partitions: '{.count}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..delete_total_count_dbs}'
                      labels:
                        environment: hms # static label
                      values:
                        delete_total_count_dbs: '{.count}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..delete_total_count_tables}'
                      labels:
                        environment: hms # static label
                      values:
                        delete_total_count_tables: '{.count}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..delete_total_count_partitions}'
                      labels:
                        environment: hms # static label
                      values:
                        delete_total_count_partitions: '{.count}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..directsql_errors}'
                      labels:
                        environment: hms # static label
                      values:
                        directsql_errors: '{.count}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..open_connections}'
                      labels:
                        environment: hms # static label
                      values:
                        open_connections: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..direct\.capacity}'
                      labels:
                        environment: hms # static label
                      values:
                        buffers_direct_capacity: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..direct\.count}'
                      labels:
                        environment: hms # static label
                      values:
                        buffers_direct_count: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..direct\.used}'
                      labels:
                        environment: hms # static label
                      values:
                        buffers_direct_used: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..mapped\.capacity}'
                      labels:
                        environment: hms # static label
                      values:
                        buffers_mapped_capacity: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..mapped\.count}'
                      labels:
                        environment: hms # static label
                      values:
                        buffers_mapped_count: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..mapped\.used}'
                      labels:
                        environment: hms # static label
                      values:
                        buffers_mapped_used: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..heap\.committed}'
                      labels:
                        environment: hms # static label
                      values:
                        memory_heap_committed: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..heap\.init}'
                      labels:
                        environment: hms # static label
                      values:
                        memory_heap_init: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..heap\.max}'
                      labels:
                        environment: hms # static label
                      values:
                        memory_heap_max: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..heap\.usage}'
                      labels:
                        environment: hms # static label
                      values:
                        memory_heap_usage: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..heap\.used}'
                      labels:
                        environment: hms # static label
                      values:
                        memory_heap_used: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..non-heap\.committed}'
                      labels:
                        environment: hms # static label
                      values:
                        memory_non_heap_committed: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..non-heap\.init}'
                      labels:
                        environment: hms # static label
                      values:
                        memory_non_heap_init: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..non-heap\.max}'
                      labels:
                        environment: hms # static label
                      values:
                        memory_non_heap_max: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..non-heap\.usage}'
                      labels:
                        environment: hms # static label
                      values:
                        memory_non_heap_usage: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..non-heap\.used}'
                      labels:
                        environment: hms # static label
                      values:
                        memory_non_heap_used: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..pools\.Code-Cache\.usage}'
                      labels:
                        environment: hms # static label
                      values:
                        memory_pools_CodeCache_usage: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..pools\.Compressed-Class-Space\.usage}'
                      labels:
                        environment: hms # static label
                      values:
                        memory_pools_CompressedClassSpace_usage: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..pools\.Metaspace\.usage}'
                      labels:
                        environment: hms # static label
                      values:
                        memory_pools_Metaspace_usage: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..total\.committed}'
                      labels:
                        environment: hms # static label
                      values:
                        memory_total_committed: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..total\.init}'
                      labels:
                        environment: hms # static label
                      values:
                        memory_total_init: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..total\.max}'
                      labels:
                        environment: hms # static label
                      values:
                        memory_total_max: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..total\.used}'
                      labels:
                        environment: hms # static label
                      values:
                        memory_total_used: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..blocked\.count}'
                      labels:
                        environment: hms # static label
                      values:
                        threads_blocked_count: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..daemon\.count}'
                      labels:
                        environment: hms # static label
                      values:
                        threads_daemon_count: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..deadlock\.count}'
                      labels:
                        environment: hms # static label
                      values:
                        threads_deadlock_count: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..new\.count}'
                      labels:
                        environment: hms # static label
                      values:
                        threads_new_count: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..runnable\.count}'
                      labels:
                        environment: hms # static label
                      values:
                        threads_runnable_count: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..terminated\.count}'
                      labels:
                        environment: hms # static label
                      values:
                        threads_terminated_count: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..timed_waiting\.count}'
                      labels:
                        environment: hms # static label
                      values:
                        threads_timed_waiting_count: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..waiting\.count}'
                      labels:
                        environment: hms # static label
                      values:
                        threads_waiting_count: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..total_count_dbs}'
                      labels:
                        environment: hms # static label
                      values:
                        total_count_dbs: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..total_count_partitions}'
                      labels:
                        environment: hms # static label
                      values:
                        total_count_partitions: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..total_count_tables}'
                      labels:
                        environment: hms # static label
                      values:
                        total_count_tables: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..HikariPool-1\.pool\.ActiveConnections}'
                      labels:
                        environment: hms # static label
                      values:
                        HikariPool_pool_ActiveConnections: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..HikariPool-1\.pool\.IdleConnections}'
                      labels:
                        environment: hms # static label
                      values:
                        HikariPool_pool_IdleConnections: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..HikariPool-1\.pool\.PendingConnections}'
                      labels:
                        environment: hms # static label
                      values:
                        HikariPool_pool_PendingConnections: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..HikariPool-1\.pool\.TotalConnections}'
                      labels:
                        environment: hms # static label
                      values:
                        HikariPool_pool_TotalConnections: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..loaded}'
                      labels:
                        environment: hms # static label
                      values:
                        classLoading_loaded: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..unloaded}'
                      labels:
                        environment: hms # static label
                      values:
                        classLoading_unloaded: '{.value}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..jvm\.pause\.extraSleepTime}'
                      labels:
                        environment: hms # static label
                      values:
                        jvm_pause_extraSleepTime: '{.count}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..jvm\.pause\.info-threshold}'
                      labels:
                        environment: hms # static label
                      values:
                        jvm_pause_info_threshold: '{.count}' # dynamic value
                    - name: hms
                      type: object
                      help: Example of sub-level value scrapes from a json
                      path: '{$..jvm\.pause\.warn-threshold}'
                      labels:
                        environment: hms # static label
                      values:
                        jvm_pause_warn_threshold: '{.count}' # dynamic value
                  headers:
                    X-Dummy: hms-json-export-header
                  """#
                }
              },
              {
                apiVersion: "v1",
                kind: "ConfigMap",
                metadata: {
                  namespace: context.namespace,
                  name: "hive-metastore-grafana-dashboard",
                  labels: {
                    "app": "grafana",
                    "grafana_dashboard": "1"
                  }
                },
                data: {
                  "hive-metastore-dashboard.json": "{\"annotations\":{\"list\":[{\"builtIn\":1,\"datasource\":{\"type\":\"datasource\",\"uid\":\"grafana\"},\"enable\":true,\"hide\":true,\"iconColor\":\"rgba(0, 211, 255, 1)\",\"name\":\"Annotations & Alerts\",\"target\":{\"limit\":100,\"matchAny\":false,\"tags\":[],\"type\":\"dashboard\"},\"type\":\"dashboard\"}]},\"editable\":true,\"fiscalYearStartMonth\":0,\"graphTooltip\":0,\"id\":40,\"links\":[],\"liveNow\":false,\"panels\":[{\"collapsed\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":0},\"id\":116,\"panels\":[],\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"refId\":\"A\"}],\"title\":\"hms service info\",\"type\":\"row\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"hms instances\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"#d44a3a\",\"value\":null},{\"color\":\"rgba(237, 129, 40, 0.89)\",\"value\":0},{\"color\":\"#299c46\",\"value\":2}]},\"unit\":\"none\"},\"overrides\":[]},\"gridPos\":{\"h\":5,\"w\":5,\"x\":0,\"y\":1},\"id\":46,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"repeatDirection\":\"h\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"count(hms_memory_heap_used{namespace=\\\"$namespace\\\"})\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"\",\"refId\":\"A\"}],\"title\":\"hms instances\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"dbs\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"#d44a3a\",\"value\":null},{\"color\":\"rgba(237, 129, 40, 0.89)\",\"value\":0},{\"color\":\"#299c46\",\"value\":2}]},\"unit\":\"none\"},\"overrides\":[]},\"gridPos\":{\"h\":5,\"w\":5,\"x\":5,\"y\":1},\"id\":156,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"repeatDirection\":\"h\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"max(hms_total_count_dbs{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"})\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"dbs\",\"range\":true,\"refId\":\"A\"}],\"title\":\"dbs\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"total tables\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"#d44a3a\",\"value\":null},{\"color\":\"rgba(237, 129, 40, 0.89)\",\"value\":0},{\"color\":\"#299c46\",\"value\":1}]},\"unit\":\"none\"},\"overrides\":[]},\"gridPos\":{\"h\":5,\"w\":5,\"x\":10,\"y\":1},\"id\":157,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"repeatDirection\":\"h\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"max(hms_total_count_tables{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"})\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"tables\",\"range\":true,\"refId\":\"A\"}],\"title\":\"tables\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"total partitions\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"#d44a3a\",\"value\":null},{\"color\":\"rgba(237, 129, 40, 0.89)\",\"value\":0},{\"color\":\"#299c46\",\"value\":1}]},\"unit\":\"none\"},\"overrides\":[]},\"gridPos\":{\"h\":5,\"w\":5,\"x\":15,\"y\":1},\"id\":158,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"repeatDirection\":\"h\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"max(hms_total_count_partitions{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"})\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"partitions\",\"range\":true,\"refId\":\"A\"}],\"title\":\"partitions\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"current open connections\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"thresholds\"},\"mappings\":[{\"options\":{\"match\":\"null\",\"result\":{\"text\":\"N/A\"}},\"type\":\"special\"}],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"#d44a3a\",\"value\":null},{\"color\":\"rgba(237, 129, 40, 0.89)\",\"value\":0},{\"color\":\"#299c46\",\"value\":1}]},\"unit\":\"none\"},\"overrides\":[]},\"gridPos\":{\"h\":5,\"w\":4,\"x\":20,\"y\":1},\"id\":159,\"links\":[],\"maxDataPoints\":100,\"options\":{\"colorMode\":\"value\",\"graphMode\":\"none\",\"justifyMode\":\"auto\",\"orientation\":\"horizontal\",\"reduceOptions\":{\"calcs\":[\"lastNotNull\"],\"fields\":\"\",\"values\":false},\"textMode\":\"auto\"},\"pluginVersion\":\"9.0.5\",\"repeatDirection\":\"h\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hms_open_connections{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"})\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"current_total_open_connections\",\"range\":true,\"refId\":\"A\"}],\"title\":\"hms open connections\",\"type\":\"stat\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Open Connections\",\"fieldConfig\":{\"defaults\":{\"color\":{\"mode\":\"palette-classic\"},\"custom\":{\"axisLabel\":\"\",\"axisPlacement\":\"auto\",\"barAlignment\":0,\"drawStyle\":\"line\",\"fillOpacity\":10,\"gradientMode\":\"none\",\"hideFrom\":{\"legend\":false,\"tooltip\":false,\"viz\":false},\"lineInterpolation\":\"linear\",\"lineWidth\":1,\"pointSize\":5,\"scaleDistribution\":{\"type\":\"linear\"},\"showPoints\":\"never\",\"spanNulls\":false,\"stacking\":{\"group\":\"A\",\"mode\":\"none\"},\"thresholdsStyle\":{\"mode\":\"off\"}},\"mappings\":[],\"thresholds\":{\"mode\":\"absolute\",\"steps\":[{\"color\":\"green\",\"value\":null},{\"color\":\"red\",\"value\":80}]},\"unit\":\"none\"},\"overrides\":[]},\"gridPos\":{\"h\":6,\"w\":24,\"x\":0,\"y\":6},\"id\":102,\"links\":[],\"maxDataPoints\":100,\"options\":{\"legend\":{\"calcs\":[\"max\",\"min\"],\"displayMode\":\"table\",\"placement\":\"bottom\"},\"tooltip\":{\"mode\":\"multi\",\"sort\":\"none\"}},\"pluginVersion\":\"9.0.5\",\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"hms_open_connections{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":2,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"title\":\" open Connections\",\"type\":\"timeseries\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Memory Usage\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":0,\"y\":12},\"hiddenSeries\":false,\"id\":160,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":false,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(container_memory_usage_bytes{container=\\\"hive-metastore\\\",namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Memory Usage\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:81\",\"format\":\"bytes\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:82\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"decimals\":3,\"description\":\"CPU Usage\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":12,\"y\":12},\"hiddenSeries\":false,\"id\":161,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":false,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(rate(container_cpu_usage_seconds_total{container=\\\"hive-metastore\\\", namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}[5m])) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"CPU Usage\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:319\",\"format\":\"short\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:320\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"collapsed\":false,\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":19},\"id\":146,\"panels\":[],\"title\":\"hms database info\",\"type\":\"row\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"total dbs\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":8,\"x\":0,\"y\":20},\"hiddenSeries\":false,\"id\":141,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":false,\"min\":false,\"show\":false,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":2,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"max(hms_total_count_dbs{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"})\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"total_dbs\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"total dbs\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:2191\",\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:2192\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"total tables\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":8,\"x\":8,\"y\":20},\"hiddenSeries\":false,\"id\":142,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":false,\"min\":false,\"show\":false,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":2,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"max(hms_total_count_tables{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"})\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"total tables\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"total tables\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:2362\",\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:2363\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"total partitions\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":8,\"x\":16,\"y\":20},\"hiddenSeries\":false,\"id\":143,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":true,\"max\":false,\"min\":false,\"show\":false,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":2,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"max(hms_total_count_partitions{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"})\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"total partitions\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"total partitions\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:2533\",\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:2534\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"collapsed\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":27},\"id\":132,\"panels\":[],\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"refId\":\"A\"}],\"title\":\"hms datanucleus\",\"type\":\"row\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"active  Connections\",\"fieldConfig\":{\"defaults\":{\"unit\":\"none\"},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":0,\"y\":28},\"hiddenSeries\":false,\"id\":162,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":false,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"maxDataPoints\":100,\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":2,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"hms_HikariPool_pool_ActiveConnections{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"active  Connections\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:134\",\"decimals\":0,\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:135\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Idle  Connections\",\"fieldConfig\":{\"defaults\":{\"unit\":\"none\"},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":12,\"y\":28},\"hiddenSeries\":false,\"id\":133,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":false,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"maxDataPoints\":100,\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":2,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"hms_HikariPool_pool_IdleConnections{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Idle  Connections\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:134\",\"decimals\":0,\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:135\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"pending Connections\",\"fieldConfig\":{\"defaults\":{\"unit\":\"none\"},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":0,\"y\":35},\"hiddenSeries\":false,\"id\":134,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":false,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"maxDataPoints\":100,\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":2,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"hms_HikariPool_pool_PendingConnections{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"pending Connections\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:134\",\"decimals\":0,\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:135\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Total Connections\",\"fieldConfig\":{\"defaults\":{\"unit\":\"none\"},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":12,\"y\":35},\"hiddenSeries\":false,\"id\":135,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":false,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"maxDataPoints\":100,\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":2,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"hms_HikariPool_pool_TotalConnections{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Total Connections\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:134\",\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:135\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"collapsed\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":42},\"id\":114,\"panels\":[],\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"refId\":\"A\"}],\"title\":\"hms instance database operation\",\"type\":\"row\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"create total dbs\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":0,\"y\":43},\"hiddenSeries\":false,\"id\":117,\"legend\":{\"alignAsTable\":false,\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":2,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hms_create_total_count_dbs{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"create total dbs\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:2077\",\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:2078\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"delete total dbs\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":12,\"y\":43},\"hiddenSeries\":false,\"id\":138,\"legend\":{\"alignAsTable\":false,\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":2,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hms_delete_total_count_dbs{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"delete total dbs\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:2134\",\"decimals\":0,\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:2135\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"create total tables\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":0,\"y\":50},\"hiddenSeries\":false,\"id\":137,\"legend\":{\"alignAsTable\":false,\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":2,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hms_create_total_count_tables{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"create total tables\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:2248\",\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:2249\",\"decimals\":0,\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"delete total tables\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":12,\"y\":50},\"hiddenSeries\":false,\"id\":140,\"legend\":{\"alignAsTable\":false,\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":2,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hms_delete_total_count_tables{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"delete total tables\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:2305\",\"decimals\":0,\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:2306\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"create total partitions\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":0,\"y\":57},\"hiddenSeries\":false,\"id\":136,\"legend\":{\"alignAsTable\":false,\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":2,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hms_create_total_count_partitions{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"create total partitions\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:2419\",\"decimals\":0,\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:2420\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"delete total partitions\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":12,\"y\":57},\"hiddenSeries\":false,\"id\":139,\"legend\":{\"alignAsTable\":false,\"avg\":false,\"current\":false,\"max\":false,\"min\":false,\"show\":true,\"total\":false,\"values\":false},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":2,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(hms_delete_total_count_partitions{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"delete total partitions\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:2476\",\"decimals\":0,\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:2477\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"collapsed\":false,\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":64},\"id\":148,\"panels\":[],\"title\":\"container resource info\",\"type\":\"row\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Memory Usage\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":8,\"x\":0,\"y\":65},\"hiddenSeries\":false,\"id\":82,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":false,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(container_memory_usage_bytes{container=\\\"hive-metastore\\\",namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Memory Usage\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:81\",\"format\":\"bytes\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:82\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"decimals\":3,\"description\":\"CPU Usage\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":8,\"x\":8,\"y\":65},\"hiddenSeries\":false,\"id\":81,\"legend\":{\"alignAsTable\":true,\"avg\":true,\"current\":false,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(rate(container_cpu_usage_seconds_total{container=\\\"hive-metastore\\\", namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}[5m])) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"CPU Usage\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:319\",\"format\":\"short\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:320\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Disk Usage\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":8,\"x\":16,\"y\":65},\"hiddenSeries\":false,\"id\":83,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":false,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"sum(rate(container_fs_reads_bytes_total{container=~\\\"hive-metastore\\\",namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\",device=~\\\"/dev/sd[a|b|c|d|e]\\\"}[2m])) by (pod)\",\"format\":\"time_series\",\"hide\":false,\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}-read\",\"range\":true,\"refId\":\"A\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"sum(rate(container_fs_writes_bytes_total{container=~\\\"hive-metastore\\\",namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\",device=~\\\"/dev/sd[a|b|c|d|e]\\\"}[2m])) by (pod)\",\"hide\":false,\"interval\":\"\",\"legendFormat\":\"{{pod}}-write\",\"range\":true,\"refId\":\"B\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Disk Usage\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:560\",\"format\":\"bytes\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:561\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"collapsed\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"gridPos\":{\"h\":1,\"w\":24,\"x\":0,\"y\":72},\"id\":28,\"panels\":[],\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"prometheus\"},\"refId\":\"A\"}],\"title\":\"JVM\",\"type\":\"row\"},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":0,\"y\":73},\"hiddenSeries\":false,\"id\":93,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":false,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(hms_memory_heap_used{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"JVM Memory Used\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:2038\",\"format\":\"decbytes\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:2039\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":12,\"y\":73},\"hiddenSeries\":false,\"id\":150,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":false,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(hms_classLoading_loaded{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"JVM Class loaded\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:2038\",\"format\":\"decbytes\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:2039\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"Heap Memory Used\",\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":0,\"y\":80},\"hiddenSeries\":false,\"id\":149,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":false,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(hms_memory_heap_used{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"Heap Memory Used\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:2038\",\"format\":\"decbytes\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:2039\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":12,\"x\":12,\"y\":80},\"hiddenSeries\":false,\"id\":151,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":false,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"paceLength\":10,\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":5,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"exemplar\":true,\"expr\":\"sum(hms_memory_non_heap_used{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"NonHeap Memory Used\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:2038\",\"format\":\"decbytes\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:2039\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"JVM thread count\",\"fieldConfig\":{\"defaults\":{\"unit\":\"none\"},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":6,\"x\":0,\"y\":87},\"hiddenSeries\":false,\"id\":152,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":false,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"maxDataPoints\":100,\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":2,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"max(hms_threads_count{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}) by (pod)\",\"format\":\"time_series\",\"interval\":\"\",\"intervalFactor\":1,\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"A\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"JVM thread count\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:134\",\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:135\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"JVM thread deadlock\",\"fieldConfig\":{\"defaults\":{\"unit\":\"none\"},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":6,\"x\":6,\"y\":87},\"hiddenSeries\":false,\"id\":144,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":false,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"maxDataPoints\":100,\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":2,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"hms_threads_deadlock_count{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}\",\"hide\":false,\"interval\":\"\",\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"C\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"JVM thread deadlock\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:134\",\"decimals\":0,\"format\":\"none\",\"logBase\":1,\"min\":\"0\",\"show\":true},{\"$$hashKey\":\"object:135\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"JVM thread blocked\",\"fieldConfig\":{\"defaults\":{\"unit\":\"none\"},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":6,\"x\":12,\"y\":87},\"hiddenSeries\":false,\"id\":155,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":false,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"maxDataPoints\":100,\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":2,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"hms_threads_blocked_count{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}\",\"hide\":false,\"interval\":\"\",\"legendFormat\":\"{{pod}}\",\"range\":true,\"refId\":\"C\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"JVM thread blocked\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:134\",\"decimals\":0,\"format\":\"none\",\"logBase\":1,\"min\":\"0\",\"show\":true},{\"$$hashKey\":\"object:135\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}},{\"aliasColors\":{},\"bars\":false,\"dashLength\":10,\"dashes\":false,\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"description\":\"jvm thread state\",\"fieldConfig\":{\"defaults\":{\"unit\":\"none\"},\"overrides\":[]},\"fill\":1,\"fillGradient\":0,\"gridPos\":{\"h\":7,\"w\":6,\"x\":18,\"y\":87},\"hiddenSeries\":false,\"id\":154,\"legend\":{\"alignAsTable\":true,\"avg\":false,\"current\":false,\"max\":true,\"min\":true,\"show\":true,\"total\":false,\"values\":true},\"lines\":true,\"linewidth\":1,\"links\":[],\"maxDataPoints\":100,\"nullPointMode\":\"null\",\"options\":{\"alertThreshold\":true},\"percentage\":false,\"pluginVersion\":\"9.0.5\",\"pointradius\":2,\"points\":false,\"renderer\":\"flot\",\"seriesOverrides\":[],\"spaceLength\":10,\"stack\":false,\"steppedLine\":false,\"targets\":[{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"hms_threads_daemon_count{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}\",\"hide\":false,\"interval\":\"\",\"legendFormat\":\"{{pod}}-daemon\",\"range\":true,\"refId\":\"B\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"hms_threads_new_count{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}\",\"hide\":false,\"interval\":\"\",\"legendFormat\":\"{{pod}}-new\",\"range\":true,\"refId\":\"D\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":false,\"expr\":\"hms_threads_runnable_count{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}\",\"hide\":false,\"interval\":\"\",\"legendFormat\":\"{{pod}}-runnable\",\"range\":true,\"refId\":\"E\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"hms_threads_terminated_count{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}\",\"hide\":false,\"interval\":\"\",\"legendFormat\":\"{{pod}}-terminated\",\"range\":true,\"refId\":\"F\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"hms_threads_timed_waiting_count{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}\",\"hide\":false,\"interval\":\"\",\"legendFormat\":\"{{pod}}-timed-waiting\",\"range\":true,\"refId\":\"G\"},{\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"editorMode\":\"code\",\"exemplar\":true,\"expr\":\"hms_threads_waiting_count{namespace=\\\"$namespace\\\",pod=~\\\"$pod\\\"}\",\"hide\":false,\"interval\":\"\",\"legendFormat\":\"{{pod}}-waiting\",\"range\":true,\"refId\":\"H\"}],\"thresholds\":[],\"timeRegions\":[],\"title\":\"jvm thread state\",\"tooltip\":{\"shared\":true,\"sort\":0,\"value_type\":\"individual\"},\"type\":\"graph\",\"xaxis\":{\"mode\":\"time\",\"show\":true,\"values\":[]},\"yaxes\":[{\"$$hashKey\":\"object:134\",\"format\":\"none\",\"logBase\":1,\"show\":true},{\"$$hashKey\":\"object:135\",\"format\":\"short\",\"logBase\":1,\"show\":true}],\"yaxis\":{\"align\":false}}],\"refresh\":false,\"schemaVersion\":36,\"style\":\"dark\",\"tags\":[\"hive\",\"hms\"],\"templating\":{\"list\":[{\"current\":{\"selected\":false,\"text\":\"Prometheus\",\"value\":\"Prometheus\"},\"hide\":0,\"includeAll\":false,\"label\":\"datasource\",\"multi\":false,\"name\":\"datasource\",\"options\":[],\"query\":\"prometheus\",\"queryValue\":\"\",\"refresh\":1,\"regex\":\"\",\"skipUrlSync\":false,\"type\":\"datasource\"},{\"current\":{\"selected\":false,\"text\":\"admin\",\"value\":\"admin\"},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"definition\":\"query_result(hms_memory_heap_used)\",\"hide\":0,\"includeAll\":false,\"label\":\"Namespace\",\"multi\":false,\"name\":\"namespace\",\"options\":[],\"query\":{\"query\":\"query_result(hms_memory_heap_used)\",\"refId\":\"StandardVariableQuery\"},\"refresh\":1,\"regex\":\"/.*namespace=\\\"([^\\\"]+).*/\",\"skipUrlSync\":false,\"sort\":1,\"tagValuesQuery\":\"\",\"tagsQuery\":\"\",\"type\":\"query\",\"useTags\":false},{\"allValue\":\".*\",\"current\":{\"selected\":false,\"text\":\"All\",\"value\":\"$__all\"},\"datasource\":{\"type\":\"prometheus\",\"uid\":\"${datasource}\"},\"definition\":\"query_result(count_over_time(hms_memory_heap_used{namespace=\\\"$namespace\\\"}[$__range]))\",\"hide\":0,\"includeAll\":true,\"label\":\"Pod\",\"multi\":true,\"name\":\"pod\",\"options\":[],\"query\":{\"query\":\"query_result(count_over_time(hms_memory_heap_used{namespace=\\\"$namespace\\\"}[$__range]))\",\"refId\":\"StandardVariableQuery\"},\"refresh\":2,\"regex\":\"/.*pod=\\\"([^\\\"]+).*/\",\"skipUrlSync\":false,\"sort\":1,\"tagValuesQuery\":\"\",\"tagsQuery\":\"\",\"type\":\"query\",\"useTags\":false}]},\"time\":{\"from\":\"now-5m\",\"to\":\"now\"},\"timepicker\":{\"refresh_intervals\":[\"5s\",\"10s\",\"30s\",\"1m\",\"5m\",\"15m\",\"30m\",\"1h\",\"2h\",\"1d\"],\"time_options\":[\"5m\",\"15m\",\"1h\",\"6h\",\"12h\",\"24h\",\"2d\",\"7d\",\"30d\"]},\"timezone\":\"\",\"title\":\"hive-metastore\",\"uid\":\"t5_CsYCnzqq\",\"version\":48,\"weekStart\":\"\"}\n"
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
                  type: "hive-metastore"
                  properties: {
                    _commonConf: {
                      "hive.metastore.uris": "thrift://\(context.name)-svc.\(context.namespace).svc.cluster.local:9083"
                    }
                    _commonConfStr: "\n\t\(strings.Join([for k, v in _commonConf {"<property>\n\t\t<name>\(k)</name>\n\t\t<value>\(v)</value>\n\t</property>"}], "\n\t"))"
                    "hiveSite": """
                    <?xml version="1.0"?>
                    <?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
                    <configuration>
                      \(strings.Join([for k, v in parameter.hiveConf{"<property>\n\t\t<name>\(k)</name>\n\t\t<value>\(v)</value>\n\t</property>"}], "\n\t") + _commonConfStr)
                    </configuration>
                    """
                    "host": "\(context.name)-svc.\(context.namespace).svc.cluster.local"
                    "port": "9083"
                    "url": "thrift://\(context.name)-svc.\(context.namespace).svc.cluster.local:9083"
                  }
                }
              },
              {
                apiVersion: "batch/v1"
                kind:       "Job"
                metadata: {
                  name: context.name + "-init-db"
                  annotations: {
                    "app.core.bdos/catalog":     "hive"
                  }
                  labels: {
                    app:                        context.name
                    "app.core.bdos/type":       "system"
                  }
                }
                spec: {
                  ttlSecondsAfterFinished: 600
                  template: {
                    spec: {
                      containers: [{
                        name: context.name + "-init-db"
                        env: [{
                          name: "HIVE_CONNECTION_USER_NAME"
                          valueFrom: secretKeyRef: {
                              name: "\(parameter.dependencies.mysql.secretName)"
                              key: "MYSQL_USER"
                          }
                        }, {
                          name:  "IMPORT_DB_HOST"
                          valueFrom: configMapKeyRef: {
                            name: "\(parameter.dependencies.mysql.configName)"
                            key: "MYSQL_HOST"
                          }
                        }, {
                          name:  "IMPORT_DB_PORT"
                          valueFrom: configMapKeyRef: {
                            name: "\(parameter.dependencies.mysql.configName)"
                            key: "MYSQL_PORT"
                          }
                        }, {
                          name:  "IMPORT_DB_DATABASE"
                          value: "\(strings.Replace("\(context.bdc)_hive_db", "-", "_", -1))"
                        }, {
                          name: "HIVE_PASSWORD"
                          valueFrom: secretKeyRef: {
                              name: "\(parameter.dependencies.mysql.secretName)"
                              key: "MYSQL_PASSWORD"
                          }
                        }]
                        command: ["/bin/bash", "-c", "/hms/sbin/init_db.sh"]
                        image: "\(context.docker_registry)/\(parameter.image)"
                        resources: {
                          limits: {
                            cpu:    "0.1"
                            memory: "128Mi"
                          }
                          requests: {
                            cpu:    "0.1"
                            memory: "128Mi"
                          }
                        }
                        volumeMounts: [{
                          name: "hms-scripts"
                          mountPath: "/hms/sbin/init_db.sh"
                          subPath: "init_db.sh"
                          readOnly: true
                        }]
                      }]
                      serviceAccountName: context.name
                      volumes: [{
                        name: "hms-scripts"
                        configMap: {
                          name: context.name + "-scripts"
                          defaultMode: 484
                        }
                      }]
                      restartPolicy: "OnFailure"
                    }
                  }
                }
              }
            ]
          },
          "traits": [
            {
              "type": "bdos-service-account",
              "properties": {
                "name": context.name
              }
            },
            {
              "type": "bdos-pod-affinity",
              "properties": {
                "antiAffinity": {
                  "app": [
                    context.name
                  ]
                },
                "topologyKey": "kubernetes.io/hostname"
              }
            },
            {
              "type": "bdos-logtail",
              "properties": {
                "name": "logs",
                "path": "/var/log/\(context.namespace)-\(context.name)"
                "promtail": {
                  "cpu": "0.1"
                  "memory": "64Mi"
                }
              }
            },
            {
              "type": "bdos-sidecar",
              "properties": {
                "name": "hms-prometheus-json-export",
                "image": "\(context.docker_registry)/prometheuscommunity/json-exporter:v0.4.0",
                "args": [
                  "--config.file=/hms-json-export.yml"
                ],
                "cpu": "0.1",
                "memory": "32Mi",
                "volumes": [
                  {
                    "name": "hms-metrics",
                    "mountPath": "/hms-json-export.yml",
                    "type": "configMap",
                    "subPath": "hms-json-export.yml",
                    "cmName": "hms-admin-cfg",
                    "readOnly": true
                  }
                ]
              }
            },
            {
              "type": "bdos-monitor",
              "properties": {
                "endpoints": [
                  {
                    "port": 7979,
                    "path": "/probe",
                    "portName": "port-tcp-7979",
                    "path_params": {
                      "target": [
                        "http://\(context.name)-svc.\(context.namespace).svc:8000/report.json"
                      ]
                    }
                  }
                ],
                "matchLabels": {
                  "app": context.name
                }
              }
            },
            {
              "type": "bdos-prometheus-rules",
              "properties": {
                "labels": {
                  "prometheus": "k8s",
                  "role": "alert-rules",
                  "release": "prometheus"
                },
                "groups": [
                  {
                    "name": "\(context.namespace)-hms.rules",
                    "rules": [
                      {
                        "alert": "hms_open_connections",
                        "expr": "hms_open_connections > 1000",
                        "duration": "2m",
                        "labels": {
                          "severity": "warning",
                          "channel": "grafana_oncall"
                        },
                        "annotations": {
                          "description": "{{$labels.pod}} hms_open_connections in 2 minute submitted to now is {{ $value }} seconds",
                          "summary": "{{$labels.pod}} hms_open_connections "
                        }
                      },
                      {
                        "alert": "hms_memory_usage",
                        "expr": "max by (pod) (container_memory_usage_bytes{container=\"hive-metastore\"}) / max by (pod) (cluster:namespace:pod_memory:active:kube_pod_container_resource_limits{container=\"hive-metastore\"}) > 0.9",
                        "duration": "2m",
                        "labels": {
                          "severity": "high",
                          "channel": "grafana_oncall"
                        },
                        "annotations": {
                          "description": "{{$labels.pod}} hms memory usage in 2 minute  is {{ $value }} seconds",
                          "summary": "{{$labels.pod}} memory used more than 90%. "
                        }
                      },
                      {
                        "alert": "jvm_memory_used",
                        "expr": "hms_memory_total_used/hms_memory_total_max > 0.9",
                        "duration": "2m",
                        "labels": {
                          "severity": "warning",
                          "channel": "grafana_oncall"
                        },
                        "annotations": {
                          "description": "{{$labels.pod}} jvm memory used is greater than 90%",
                          "summary": "{{$labels.pod}} jvm memory used is greater than 90% "
                        }
                      },
                      {
                        "alert": "hms_threads_deadlock_count",
                        "expr": "hms_threads_deadlock_count > 0",
                        "duration": "2m",
                        "labels": {
                          "severity": "high",
                          "channel": "grafana_oncall"
                        },
                        "annotations": {
                          "description": "{{$labels.pod}} hms_threads_deadlock_count in 2 minute  is {{ $value }} seconds",
                          "summary": "{{$labels.pod}} hms_threads_deadlock_count "
                        }
                      }
                    ]
                  }
                ]
              }
            }
          ]
        },
        {
          "name": "\(context.name)-\(context.namespace)-cluster-role",
          "type": "bdos-cluster-role",
          "properties": {
            "rules": [
              {
                "apiGroups": [
                  "*"
                ],
                "resources": [
                  "secrets",
                  "configmaps"
                ],
                "verbs": [
                  "get",
                  "list",
                  "create",
                  "update",
                  "patch"
                ]
              }
            ]
          }
        },
        {
          "name": "\(context.name)-\(context.namespace)-cluster-role-binding",
          "type": "bdos-cluster-role-binding",
          "properties": {
            "clusterRoleRefName": "\(context.name)-\(context.namespace)-cluster-role",
            "serviceAccounts": [
              {
                "serviceAccountName": context.name,
                "namespace": context.namespace
              }
            ]
          }
        }
      ],
      "policies": [
        {
          "name": "shared-resource",
          "type": "shared-resource",
          "properties": {
            "rules": [
              {
                "selector": {
                  "componentNames": [
                    "hive-metastore-grafana-dashboard"
                  ]
                }
              }
            ]
          }
        },
        {
          "name": "apply-once",
          "type": "apply-once",
          "properties": {
            "enable": true,
            "rules": [
              {
                "strategy": {
                  "path": [
                    "*"
                  ]
                },
                "selector": {
                  "resourceTypes": [
                    "Job"
                  ]
                }
              },
            ]
          }
        }
      ]
    }
  }
  parameter: {
    // +ui:title=组件依赖
    // +ui:order=1
    dependencies: {
      // +ui:description=HDFS 上下文
      // +ui:order=3
      // +err:options={"required":"请先安装 HDFS"}
      hdfsConfigMapName: string
      // +ui:description=MySQL 配置
      // +ui:order=6
      mysql: {
        // +ui:description=MySQL 上下文
        // +ui:order=1
        // +err:options={"required":"请先安装 MySQL"}
        configName: string
        // +ui:description=MySQL 密钥
        // +ui:order=2
        // +err:options={"required":"请先安装 MySQL"}
        secretName: string
      }
    }
    // +ui:description=副本数
    // +ui:order=2
    // +minimum=1
    replicas: *2 | int
    // +ui:description=资源规格
    // +ui:order=7
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
    // +ui:description=自定义 hive-site.xml 内容
    // +ui:order=8
    hiveConf: *{
      "hive.execution.engine": "spark",
      "hive.scratch.dir.permission": "733",
      "hive.security.authorization.manager": "org.apache.hadoop.hive.ql.security.authorization.plugin.sqlstd.SQLStdHiveAuthorizerFactory",
      "hive.security.authenticator.manager": "org.apache.hadoop.hive.ql.security.HadoopDefaultAuthenticator",
      "hive.metastore.warehouse.dir": "/user/hive/warehouse",
      "hive.metastore.metrics.enabled": "true",
      "hive.cluster.delegation.token.store.class": "org.apache.hadoop.hive.thrift.DBTokenStore"
    } | {...}
    // +ui:description=是否开启多租户
    // +ui:order=9
    // +ui:hidden=true
    multiTenancy: *false | bool
    // +ui:description=镜像版本
    // +ui:order=100
    // +ui:options={"disabled":true}
    image: *"ltc-hms:v1.0.0-3.1.3" | string
  }
}