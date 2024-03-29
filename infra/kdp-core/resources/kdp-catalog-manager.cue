package main

_CatalogManagerName: "kdp-catalog-manager"
_CatalogManagerPort: 8888

_kdpCatalogManager: {
	name: parameter.namePrefix + _CatalogManagerName

	type: "k8s-objects"
	properties: {
		objects: [
			// Deployment
			{
				apiVersion: "apps/v1"
				kind: "Deployment"
				metadata: {
					name: _CatalogManagerName
					namespace: "\(parameter.namespace)"
					labels: {
						app: _CatalogManagerName
						"reloader.stakater.com/search": "true"
					}
				}
				spec: {
					replicas: 1
					selector: matchLabels: app: _CatalogManagerName
					template: {
						metadata: labels: app: _CatalogManagerName
						spec: {
							imagePullSecrets: [
								{name: "\(parameter.imagePullSecret)"}
							]
							serviceAccountName: _CatalogManagerName
							volumes: [
								{
									name: "catalog"
									emptyDir: {}
								},
								{
									name: "logs"
									emptyDir: {}
								},
								{
									name: "promtail-conf"
									configMap: {
										name: "promtail-conf"
										defaultMode: 420
									}
								}
							]
							initContainers: [
								{
									name: "prep-catalog"
									image: "\(parameter.registry)/kubernetes-data-platform:\(_version.kdp)"
									imagePullPolicy: "IfNotPresent"
									command: ["sh", "-c", "cp -vrf catalog/* /opt"]
									volumeMounts: [
										{
											name: "catalog"
											mountPath: "/opt/"
										}
									]
								},
								{
									name: "apply-xdef"
									image: "\(parameter.registry)/kdp-oam-operator/bdcctl:\(_version.operator)"
									imagePullPolicy: "IfNotPresent"
									command: ["sh", "-c", "for c in `find /opt/*/x-definitions/*.cue`; do bdcctl def apply $c; done"]
									volumeMounts: [
										{
											name: "catalog"
											mountPath: "/opt/"
										}
									]
								},
							]
							containers: [
								{
									name: _CatalogManagerName
									image: "\(parameter.registry)/kdp-catalog-manager:\(_version.catalogManager)"
									imagePullPolicy: "IfNotPresent"
									command: ["/bin/bash", "-c", "$RUNTIME_HOME/entrypoint.sh"]
									ports: [
										{
											containerPort: _CatalogManagerPort
											protocol: "TCP"
										}
									]
									env: [
										{
											name: "LOG_LEVEL"
											value: "INFO"
										},
										{
											name: "HTTP_TIME_OUT"
											value: "10"
										},
										{
											name: "HTTP_MAX_RETRIES"
											value: "3"
										},
										{
											name: "WORKER_NUM"
											value: "4"
										},
										{
											name: "OAM_BASE_URL"
											value: "http://\(_APIServerName):\(_APIServerPort)"
										},
										{
											name: "DASHBOARD_URL"
											value: _GrafanaUrl
										},
										{
											name: "SUPPORT_LANG"
											value: "zh,en"
										},
									]
									resources: {}
									volumeMounts: [
										{
											name: "catalog"
											mountPath: "/opt/bdos/kdp/bdos-core/catalog"
										},
										{
											name: "logs"
											mountPath: "/opt/bdos/kdp/bdos-core/logs"
										}
									]
									startupProbe: {
										httpGet: {
											path: "/"
											port: _CatalogManagerPort
											scheme: "HTTP"
										}
										failureThreshold: 30
										periodSeconds: 10
									}
									livenessProbe: {
										httpGet: {
											path: "/"
											port: _CatalogManagerPort
											scheme: "HTTP"
										}
										periodSeconds: 10
										failureThreshold: 3
									}
									readinessProbe: {
										httpGet: {
											path: "/"
											port: _CatalogManagerPort
											scheme: "HTTP"
										}
										periodSeconds: 10
										failureThreshold: 3
									}
								},
								{
									name: "logging-sidecar"
									image: "\(parameter.registry)/grafana/promtail:2.9.3"
									imagePullPolicy: "IfNotPresent"
									args: ["-config.file=/etc/promtail/config.yaml", "-config.expand-env=true"]
									env: [
										{
											name: "LOKI_PUSH_URL"
											valueFrom: configMapKeyRef: {
												name: "promtail-args"
												key: "LOKI_PUSH_URL"
											}
										},
										{
											name: "TZ"
											value: "Asia/Shanghai"
										},
										{
											name: "PROMTAIL_PORT"
											value: "3101"
										},
										{
											name: "PROMTAIL_NAMESPACE"
											value: "\(parameter.namespace)"
										},
										{
											name: "PROMTAIL_CatalogManagerName"
											value: _CatalogManagerName
										},
										{
											name: "POD_NAME"
											valueFrom: fieldRef: {
												apiVersion: "v1"
                  								fieldPath: "metadata.name"
											}
										},
										{
											name: "PROMTAIL_LOG_PATH"
											value: "/var/log/" + _CatalogManagerName
										}
									]
									resources: {}
									volumeMounts: [
										{
											name: "logs"
											mountPath: "/var/log/" + _CatalogManagerName
										},
										{
											name: "promtail-conf"
											mountPath: "/etc/promtail"
										}
									]
								}
							]
						}
					}
				}
			},
			// Service
			{
				apiVersion: "v1"
				kind: "Service"
				metadata: {
					name: _CatalogManagerName
					namespace: "\(parameter.namespace)"
				}
				spec: {
					ports: [
						{
							port: _CatalogManagerPort
							targetPort: _CatalogManagerPort
						}
					]
					selector: app: _CatalogManagerName
				}
			},
			//RBAC
			{
				apiVersion: "v1"
				kind: "ServiceAccount"
				metadata: {
					name: _CatalogManagerName
					namespace: parameter.namespace
					labels: app: _CatalogManagerName
				}
			},
			{
				apiVersion: "rbac.authorization.k8s.io/v1"
				kind: "ClusterRole"
				metadata: {
					name: _CatalogManagerName
					labels: app: _CatalogManagerName
				}
				rules: [
					{
						verbs: ["*"]
						apiGroups: ["bdc.kdp.io"]
						resources: ["xdefinitions"]
					},
				]
			},
			{
				apiVersion: "rbac.authorization.k8s.io/v1"
				kind: "ClusterRoleBinding"
				metadata: {
					name: _CatalogManagerName,
					labels: app: _CatalogManagerName
				}
				subjects: [
					{
						kind: "ServiceAccount"
						name: _CatalogManagerName
						namespace: parameter.namespace
					}
				]
				roleRef: {
					apiGroup: "rbac.authorization.k8s.io"
					kind: "ClusterRole"
					name: _CatalogManagerName
				}
			}
		]
	}
}
