package main

mysqlComponents: [
	mysql,
	_mysqlK8sObjects,
]

mysqlPolicies: [
	if parameter.xtrabackup.enabled == true {
		{
		name: "garbage-collect"
		properties: {
			rules: [{
				selector: {
					componentNames: ["mysql-backup-pvc"]
				}
				strategy: "never"
			}]
		}
		type: "garbage-collect"
		}
	}
]

mysqlWorkflowSteps: [
	{
		type: "apply-component"
		name: "apply-k8s-objects"
		properties: component: parameter.namePrefix + "mysql-k8s-objects"
	}, {
		type: "apply-component"
		name: "apply-mysql-cluster"
		properties: component: parameter.namePrefix + "mysql"
	}
]

_mysqlK8sObjects: {
	name: parameter.namePrefix + "mysql-k8s-objects"
	type: "k8s-objects"
	properties: objects: [
		if parameter.mysqlArch == "replication" {
			_mysqlService,
		}
	] + _mysqlSecrets + _mysqlBackupSuits
}

_myCnf: """
[mysqld]
default_authentication_plugin=mysql_native_password
skip-name-resolve
explicit_defaults_for_timestamp
basedir=/opt/bitnami/mysql
plugin_dir=/opt/bitnami/mysql/lib/plugin
port=3306
socket=/opt/bitnami/mysql/tmp/mysql.sock
datadir=/bitnami/mysql/data
tmpdir=/opt/bitnami/mysql/tmp
max_allowed_packet=16M
bind-address=0.0.0.0
pid-file=/opt/bitnami/mysql/tmp/mysqld.pid
log-error=/opt/bitnami/mysql/logs/mysqld.log
character-set-server=UTF8
collation-server=utf8_general_ci

skip-host-cache
skip-ssl
symbolic-links=0
default-time-zone='+08:00'

enforce_gtid_consistency=ON
gtid_mode=ON
binlog_checksum=NONE
binlog_row_image=minimal
expire_logs_days=3

max_connections=3000
max_user_connections=1000
innodb_buffer_pool_size=6442450944

slow-query-log=1
slow-query-log-file=/opt/bitnami/mysql/logs/slow-query.log
long_query_time=10
log-queries-not-using-indexes

[client]
port=3306
socket=/opt/bitnami/mysql/tmp/mysql.sock
default-character-set=UTF8
plugin_dir=/opt/bitnami/mysql/lib/plugin

[manager]
port=3306
socket=/opt/bitnami/mysql/tmp/mysql.sock
pid-file=/opt/bitnami/mysql/tmp/mysqld.pid
"""

mysql: {
	name: parameter.namePrefix + "mysql"
	properties: {
		url: "\(parameter.helmURL)"
		chart: "mysql"
		releaseName: parameter.namePrefix + "mysql"
		repoType: "helm"
		targetNamespace: "\(parameter.namespace)"
		values: {
			global: {
				imageRegistry: "\(parameter.registry)"
				imagePullSecrets: ["\(parameter.imagePullSecret)"]
				storageClass: "\(parameter.storageConfig.storageClassMapping.localDisk)"
			}
			image: debug: parameter.systemMysql.debug
			architecture: "\(parameter.mysqlArch)"
			auth: {
				createDatabase:  true
				database: "\(parameter.systemMysql.users.kdpAdmin.database)"
				username: "\(parameter.systemMysql.users.kdpAdmin.user)"
				existingSecret: parameter.namePrefix + "mysql-secret-private"
			}
			initdbScripts: {
				"init.sql": """
					-- 1. grant DBA privileges to BDOS admin user
					GRANT ALL PRIVILEGES ON *.* TO `\(parameter.systemMysql.users.kdpAdmin.user)`@`%` WITH GRANT OPTION;
					FLUSH PRIVILEGES;
				"""
			}
			primary: {
				configuration: _myCnf
				persistence: {
					enabled: true
					size: "\(parameter.mysqlDiskSize)"
				}
				pdb: {
					create: true
				}
				if parameter.xtrabackup.enabled == true {
					extraVolumes: [{
						name: "mysql-backup"
						persistentVolumeClaim: {
							claimName: parameter.namePrefix + "data-mysql-backup"
						}
					}, {
						name: "mysql-backup-pubkey"
						secret: {
							items: [{
								path: "id_rsa.pub"
								key:  "ssh-publickey"
								mode: 420
							}]
							secretName: parameter.namePrefix + "mysql-backup-keypair"
						}
					}]
					service: {
						extraPorts: [{
							name:       "mgt"
							protocol:   "TCP"
							port:       2222
							targetPort: "mgt"
						}]
					}
					sidecars: [{
						name:            "xtrabackup"
						image:           "\(parameter.registry)/mysql-toolkit/xtrabackup-ssh:8.0.22"
						imagePullPolicy: "IfNotPresent"
						ports: [{
							name:          "mgt"
							containerPort: 2222
							protocol:      "TCP"
						}]
						resources: {
							limits: {
								cpu:    parameter.xtrabackup.resources.limits.cpu
								memory: parameter.xtrabackup.resources.limits.memory
							}
							requests: {
								cpu:    parameter.xtrabackup.resources.requests.cpu
								memory: parameter.xtrabackup.resources.requests.memory
							}
						}
						volumeMounts: [{
							name:      "data"
							mountPath: "/bitnami/mysql"
						}, {
							name:      "mysql-backup"
							mountPath: "/backup"
						}, {
							name:      "mysql-backup-pubkey"
							mountPath: "/opt"
						}]
					}]
				}
			}
			secondary: {
				replicaCount: 1
				configuration: _myCnf
				persistence: {
					enabled: true
					size: "\(parameter.mysqlDiskSize)"
				}
				pdb: {
					create: true
				}
			}
			metrics: {
				enabled: false
				serviceMonitor: enabled: false
				serviceMonitor: labels: {
					release: "prometheus"
				}
			}
		}
		version: "9.23.0"
	}
	type: "helm"
	dependsOn: [parameter.namePrefix + "mysql-k8s-objects"]
}
