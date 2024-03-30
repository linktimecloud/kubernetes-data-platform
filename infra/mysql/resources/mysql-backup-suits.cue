package main

_mysqlBackupSuits: {
	if parameter.xtrabackup.enabled == false {
		[]
	}
	if parameter.xtrabackup.enabled == true {
		[
			{
				apiVersion: "v1"
				kind:       "PersistentVolumeClaim"
				metadata: {
					name:      parameter.namePrefix + "data-mysql-backup"
					namespace: "\(parameter.namespace)"
				}
				spec: {
					accessModes: ["ReadWriteOnce"]
					resources: {
						requests: {
							storage: "\(parameter.xtrabackup.diskSize)"
						}
					}
					storageClassName: "\(parameter.storageConfig.storageClassMapping.localDisk)"
				}
			},
			{
				apiVersion: "v1"
				data: {
					"ssh-privatekey": "LS0tLS1CRUdJTiBPUEVOU1NIIFBSSVZBVEUgS0VZLS0tLS0KYjNCbGJuTnphQzFyWlhrdGRqRUFBQUFBQkc1dmJtVUFBQUFFYm05dVpRQUFBQUFBQUFBQkFBQUJsd0FBQUFkemMyZ3RjbgpOaEFBQUFBd0VBQVFBQUFZRUF3eWIyU0poMEpqWGM2Uy9Ddm9GVjdXb3EwQkdhY3Zxbm00L0hHWm1WNndZOHdUcDlQQjVJCnJtcDRvbmI5SEV3T05IZzBkL0NtbnF0SE13VkNSRTZHZWg1bzhGWVR5dGIwQkxEbklKbXVmWEdXYXp6ajJ6NzNoM0t1WDkKWWJydU8wWjJ6YnZhWUFSWVhWdjBzVWlxejE2cXVTY1JpYUpHaVFzb2FIYXYrZTRoVWNEOE9UdnZnUFIwQWFLcW1ZZGZtSQpNM3ZQeXBiNXRxVUlwYlpjKzlkMFNocjdEdFphYXlMT2xYdEhPYlJvYWlWZy9RUW02bkFkaFVCZWU5S09zbm1EeWlmd1NRCjhuY0haWEVlVFNuUkUyWWpselNxaWt3R1VzZ0NDbjdtdkUzY2Y1SWRsdHdZZTJMS0I2Q3BKa2Y1Uyt2SFVRTlNZbjMrdEwKbUtlY1ZIZXNaV1BLR2twNHpOdThHM2NZTlJzMUU3MTh0QXpoSlp4dzJ4SkNNZHk2N1VhV0I1TUgrWWc0U3lDYitxMjVqdApzSHcvOXFQMlFUandDUldXVDJaY09ZRGE3U3V5dGdRT0FYOUF5UEwzZXNIZDhQb0FsYkV6eFB2TmdUWExqYWdsQm9MNUZQCjNUTzBGYytVMy9TOHhVSDZyS3hVdkZycW04cHRHeHVULzhsbWNQaWhBQUFGZU9nRHRqVG9BN1kwQUFBQUIzTnphQzF5YzIKRUFBQUdCQU1NbTlraVlkQ1kxM09rdndyNkJWZTFxS3RBUm1uTDZwNXVQeHhtWmxlc0dQTUU2ZlR3ZVNLNXFlS0oyL1J4TQpEalI0Tkhmd3BwNnJSek1GUWtST2hub2VhUEJXRThyVzlBU3c1eUNacm4xeGxtczg0OXMrOTRkeXJsL1dHNjdqdEdkczI3CjJtQUVXRjFiOUxGSXFzOWVxcmtuRVltaVJva0xLR2gyci9udUlWSEEvRGs3NzREMGRBR2lxcG1IWDVpRE43ejhxVytiYWwKQ0tXMlhQdlhkRW9hK3c3V1dtc2l6cFY3UnptMGFHb2xZUDBFSnVwd0hZVkFYbnZTanJKNWc4b244RWtQSjNCMlZ4SGswcAowUk5tSTVjMHFvcE1CbExJQWdwKzVyeE4zSCtTSFpiY0dIdGl5Z2VncVNaSCtVdnJ4MUVEVW1KOS9yUzVpbm5GUjNyR1ZqCnlocEtlTXpidkJ0M0dEVWJOUk85ZkxRTTRTV2NjTnNTUWpIY3V1MUdsZ2VUQi9tSU9Fc2dtL3F0dVk3YkI4UC9hajlrRTQKOEFrVmxrOW1YRG1BMnUwcnNyWUVEZ0YvUU1qeTkzckIzZkQ2QUpXeE04VDd6WUUxeTQyb0pRYUMrUlQ5MHp0QlhQbE4vMAp2TVZCK3F5c1ZMeGE2cHZLYlJzYmsvL0pabkQ0b1FBQUFBTUJBQUVBQUFHQUZFak1lS2RBQzJpMTJaY1pTdXZ1bm9yV2dHCklVQjdkK0RIRlpaSlBPUFd1Y2pRa2pVMGhpalo2TGczZVN2NG80UDhQdTBEaTNXTzY4cTlUMEdsMS9KTnBjVmY3Y2Q4ejMKK0RUYkVVeG9FcW5uMUtXem1XcG1HRElYWmVhL1llSlJNaDdpaUVmazUxVU43cUJETmxiY0NOUmttRlRTVU01OW05RFg2bwpzL1hJaU5MaVpLQ1NPSGt3UmFzK3lFNkY1VGhlWnNwc1lpbHBWNDNLQ2o4WmxuZ1B4azlCbmJ0QjhlRWZPS1o3a1UwVk9wClRTTk5XRGpuR0o2a000S2pTbkhPem5YYW85UVZ6b1NSUDN4SGJpRjlnN05LbUZsd2NsREcxTE91cHhMdGM2Nm1hc0pHKzgKeEx6b1RVTFlRWDBTWWFzU1dqSjNQeTN0S24xVmQrY29yZ1Jna05IU2tUN0JsajE3WE9aQzVjRUNtaHNUc2hCU211dmRqNwpQa3B0SFhJQzRWK21TWEYydmxRWWMyOG9TLzJYTVBsK2oyVE5lL0xXV2haU0hKL28zNVRRS0p4VEVlN3l1M2JxUUdHWTE3CnltczlrbzNHRG5iYjZxRmlrN2ZPdjc0TzR6S25XSDJScW15azB4TUdUZWxTb3I1M09qYUErcTNsT045RE9LZ0hOQkFBQUEKd0RkZnk1UkxEUnVkK3JyOWl1RHNoZWpZOVVtd3pqTVlFNCs2bncrbGRyd1JEUTdYZllwSXJYQk5KTFJmM05ObE1yR09pYQo5NWswbjhLL2x4Z1ZEa3Zpek9BUEI0YVowK2FNWUxsK0hoSWtEV2RKaXVRZ2puQWVVYzRLSlhRTDZQUjdZVFUyQ2JnbW9BCnR5OWJ0cCtXUDByeDUxUldKSHBhK1RjYUdycWpWNXZXV2c4K0x2dE1nU0R4L1dEeFo0WnJPOTVBbFk2bXR0aE1EdnlhcmQKVEZidzMwQnRBMUdBYXBHcU5hK0ZWQ2ZNZGQ0NXQ1aEtodjdob3VaMFdzbFEvM1NRQUFBTUVBN3pVOWRLSUdGSjlKYVExNwpMNks1elA5dlRlQjQxT0VMOWZmTytKVHlKT1hUMVdrWDdPWCtPTm16RjdVMkVmVWFuNEM2dUxWMURMRXhxL3owSXNJQTBvCjV4aTZSUEVycVcvYmVCTW1DMWxad0JUc0Y0RGk4KzcxNllGQ2pETGVOdm5Gbi9qY1NMVVUrallOdnlXWU1zK3RsSFdFMUkKZHcvdVFEZFhLNlRUVmpqUWNUZVcxRi92WFZ0TVcvZXUzaEV2VHd4STgvUEg4ZDd4TkRYaTAwYUpOMG1SQ0I5WnpvTXEvVApBVzdNNFV2L3NwVGh2a3NyZW9vL1BCenNJSHl4NE5BQUFBd1FEUTJnRVZ0dUNmUHU5eFVJcmx6a0YyRkZrNzZwREx3SU9NCkJQSFBjb20zclUydXVWT2w2SWtZbE9zOUhRUzkrV1BOa2svaUY1NjZYY2MvT0I1ci9EZFc5SDZuK0taTThoaVpHZ0ZkV0YKUDBYd3R5cEhlcGNGcjUvaThIWkhnZzFGUzl6aXFBMGFZUm5HZG9FOGV3L1BDaThQQ0MyUHBFUmU4Z2hNMUQ5eTFjVFVmOApONWd1OFZPa0FsNzJoK2tPU3JQenl5TU5CeVd1eUx4YnpCemlCSlJnRTBkemZtVGFPR3kweFI0eDBVbURJeE1FYjU3TTJPCjd1a2owN0MxT3NzK1VBQUFBQUFRSUQKLS0tLS1FTkQgT1BFTlNTSCBQUklWQVRFIEtFWS0tLS0tCg=="
					"ssh-publickey":  "c3NoLXJzYSBBQUFBQjNOemFDMXljMkVBQUFBREFRQUJBQUFCZ1FEREp2WkltSFFtTmR6cEw4SytnVlh0YWlyUUVacHkrcWViajhjWm1aWHJCanpCT24wOEhraXVhbmlpZHYwY1RBNDBlRFIzOEthZXEwY3pCVUpFVG9aNkhtandWaFBLMXZRRXNPY2dtYTU5Y1paclBPUGJQdmVIY3E1ZjFodXU0N1JuYk51OXBnQkZoZFcvU3hTS3JQWHFxNUp4R0pva2FKQ3lob2RxLzU3aUZSd1B3NU8rK0E5SFFCb3FxWmgxK1lnemU4L0tsdm0ycFFpbHRsejcxM1JLR3ZzTzFscHJJczZWZTBjNXRHaHFKV0Q5QkNicWNCMkZRRjU3MG82eWVZUEtKL0JKRHlkd2RsY1I1TktkRVRaaU9YTktxS1RBWlN5QUlLZnVhOFRkeC9raDJXM0JoN1lzb0hvS2ttUi9sTDY4ZFJBMUppZmY2MHVZcDV4VWQ2eGxZOG9hU25qTTI3d2JkeGcxR3pVVHZYeTBET0VsbkhEYkVrSXgzTHJ0UnBZSGt3ZjVpRGhMSUp2NnJibU8yd2ZELzJvL1pCT1BBSkZaWlBabHc1Z05ydEs3SzJCQTRCZjBESTh2ZDZ3ZDN3K2dDVnNUUEUrODJCTmN1TnFDVUdndmtVL2RNN1FWejVUZjlMekZRZnFzckZTOFd1cWJ5bTBiRzVQL3lXWncrS0U9IAo="
				}
				kind: "Secret"
				metadata: {
					name:      parameter.namePrefix + "mysql-backup-keypair"
					namespace: "\(parameter.namespace)"
				}
				type: "kubernetes.io/ssh-auth"
			}, 
			{
				apiVersion: "v1"
				data: {
					"entrypoint.sh": """
				#!/bin/bash
				
				declare SSH_USER=${SSH_USER:-\"devops\"}
				declare SSH_PORT=${SSH_PORT:-\"2222\"}
				declare SSH_PKEY=${SSH_PKEY:-\"/opt/id_rsa\"}
				declare MYSQL_SERVER_ADDR=${MYSQL_SERVER_ADDR:-\"mysql-primary\"}
				declare MYSQL_SERVER_PORT=${MYSQL_SERVER_PORT:-\"3306\"}
				declare MYSQL_USERNAME=${MYSQL_USERNAME:-\"\(parameter.systemMysql.users.kdpAdmin.user)\"}
				declare MYSQL_PASSWORD=${MYSQL_PASSWORD:-\"\"}
				
				case \"$1\" in
				\"full\")
					BACKUP_OPTS=\"-f\"
					;;
				\"inc\")
					BACKUP_OPTS=\"-i\"
					;;
				esac
				
				if [[ -z $BACKUP_OPTS ]]; then
				echo \"Error: backup mode is not specified, either specify '-f' or '-i'.\"
				exit 1
				fi
				
				ssh \\
				-oStrictHostKeyChecking=no \\
				-oUserKnownHostsFile=/dev/null \\
				-i ${SSH_PKEY} \\
				-p ${SSH_PORT} \\
				${SSH_USER}@${MYSQL_SERVER_ADDR} \\
				\"backup.sh -u ${MYSQL_USERNAME} -p ${MYSQL_PASSWORD} -H ${MYSQL_SERVER_ADDR} -P ${MYSQL_SERVER_PORT} ${BACKUP_OPTS}\"
				"""
				}
				kind: "ConfigMap"
				metadata: {
					name:      parameter.namePrefix + "mysql-backup-entrypoint"
					namespace: "\(parameter.namespace)"
				}
			},
			{
				apiVersion: "batch/v1"
				kind:       "CronJob"
				metadata: {
					name:      parameter.namePrefix + "mysql-backup-cron-full"
					namespace: "\(parameter.namespace)"
				}
				spec: {
					concurrencyPolicy: "Forbid"
					jobTemplate: {
						spec: {
							template: {
								spec: {
									containers: [{
										name: "full-backup"
										env: [{
											name: "MYSQL_PASSWORD"
											valueFrom: {
												secretKeyRef: {
													name: parameter.namePrefix + "mysql-secret-private"
													key:  "mysql-password"
												}
											}
										}]
										command: ["/bin/bash", "/usr/local/bin/entrypoint.sh", "full"]
										image:           "\(parameter.registry)/kroniak/ssh-client:3.15"
										imagePullPolicy: "IfNotPresent"
										volumeMounts: [{
											name:      "ssh-privatekey"
											mountPath: "/opt"
										}, {
											name:      "entrypoint"
											mountPath: "/usr/local/bin"
										}]
									}]
									imagePullSecrets: [{
										name: "\(parameter.imagePullSecret)"
									}]
									restartPolicy: "OnFailure"
									volumes: [{
										name: "ssh-privatekey"
										secret: {
											items: [{
												path: "id_rsa"
												key:  "ssh-privatekey"
												mode: 384
											}]
											secretName: parameter.namePrefix + "mysql-backup-keypair"
										}
									}, {
										name: "entrypoint"
										configMap: {
											name: parameter.namePrefix + "mysql-backup-entrypoint"
										}
									}]
								}
							}
						}
					}
					schedule:                "0 */24 * * *"
					ttlSecondsAfterFinished: 86400
				}
			},
			{
				apiVersion: "batch/v1"
				kind:       "CronJob"
				metadata: {
					name:      parameter.namePrefix + "mysql-backup-cron-incremental"
					namespace: "\(parameter.namespace)"
				}
				spec: {
					jobTemplate: {
						spec: {
							template: {
								spec: {
									containers: [{
										name: "full-backup"
										env: [{
											name: "MYSQL_PASSWORD"
											valueFrom: {
												secretKeyRef: {
													name: parameter.namePrefix + "mysql-secret-private"
													key:  "mysql-password"
												}
											}
										}]
										command: ["/bin/bash", "/usr/local/bin/entrypoint.sh", "inc"]
										image:           "\(parameter.registry)/kroniak/ssh-client:3.15"
										imagePullPolicy: "IfNotPresent"
										volumeMounts: [{
											name:      "ssh-privatekey"
											mountPath: "/opt"
										}, {
											name:      "entrypoint"
											mountPath: "/usr/local/bin"
										}]
									}]
									imagePullSecrets: [{
										name: "\(parameter.imagePullSecret)"
									}]
									restartPolicy: "OnFailure"
									volumes: [{
										name: "ssh-privatekey"
										secret: {
											items: [{
												path: "id_rsa"
												key:  "ssh-privatekey"
												mode: 384
											}]
											secretName: parameter.namePrefix + "mysql-backup-keypair"
										}
									}, {
										name: "entrypoint"
										configMap: {
											name: parameter.namePrefix + "mysql-backup-entrypoint"
										}
									}]
								}
							}
						}
					}
					schedule:                "0 * * * *"
					ttlSecondsAfterFinished: 3600
				}
			}
		]
	}
}
	
