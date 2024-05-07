package main

_UXName: "\(parameter.webName)"
_UXPort: parameter.webPort

_kdpUX: {
	name: parameter.namePrefix + _UXName
	type: "k8s-objects"
	properties: {
		objects: [
			// Deployment
			{
				apiVersion: "apps/v1"
				kind: "Deployment"
				metadata: {
					name: _UXName
					namespace: "\(parameter.namespace)"
					labels: {
						app: _UXName
						"reloader.stakater.com/search": "true"
					}
				}
				spec: {
					replicas: 1
					selector: matchLabels: app: _UXName
					template: {
						metadata: labels: app: _UXName
						spec: {
							imagePullSecrets: [
								{name: "\(parameter.imagePullSecret)"}
							]
							volumes: [
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
							containers: [
								{
									name: _UXName
									image: "\(parameter.registry)/linktimecloud/kdp-ux:\(_version.ux)"
									imagePullPolicy: "IfNotPresent"
									command: ["npm", "start"]
									ports: [
										{
											containerPort: _UXPort
											protocol: "TCP"
										}
									]
									env: [
										{
											name: "LOCAL_USER_NAME"
											value: "admin"
										},
										{
											name: "CATALOG_MANAGER_DOMAIN"
											value: "http://\(_CatalogManagerName):\(_CatalogManagerPort)"
										},
										{
											name: "OAM_API_SERVER_DOMAIN"
											value: "http://\(_APIServerName):\(_APIServerPort)"
										},
										{
											name: "PROMETHEUS_SERVICE"
											value: _PrometheusUrl
										},
										{
											name: "LOKI_SERVICE"
											value: _LokiUrl
										},
										{
											name: "MYSQL_DATABASE"
											value: "kdp_ux_db"
										},
										{
											name: "MYSQL_HOST"
											valueFrom: configMapKeyRef: {
												name: "mysql-setting"
												key: "MYSQL_HOST"
											}
										},
										{
											name: "MYSQL_PORT"
											valueFrom: configMapKeyRef: {
												name: "mysql-setting"
												key: "MYSQL_PORT"
											}
										},
										{
											name: "MYSQL_USER"
											valueFrom: secretKeyRef: {
												name: "mysql-secret"
												key: "MYSQL_USER"
											}
										},
										{
											name: "MYSQL_PASSWORD"
											valueFrom: secretKeyRef: {
												name: "mysql-secret"
												key: "MYSQL_PASSWORD"
											}
										}
									]
									resources: {}
									volumeMounts: [
										{
											name: "logs"
											mountPath: "/app/logs"
										}
									]
									livenessProbe: {
										httpGet: {
											path: "/liveness"
											port: _UXPort
											scheme: "HTTP"
										}
										initialDelaySeconds: 30
										timeoutSeconds: 3
										periodSeconds: 10
										successThreshold: 1
										failureThreshold: 3
									}
									readinessProbe: {
										httpGet: {
											path: "/readiness"
											port: _UXPort
											scheme: "HTTP"
										}
										initialDelaySeconds: 30
										timeoutSeconds: 3
										periodSeconds: 10
										successThreshold: 1
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
											name: "PROMTAIL_UXName"
											value: _UXName
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
											value: "/var/log/" + _UXName + "/{error,response,log}"
										}
									]
									resources: {}
									volumeMounts: [
										{
											name: "logs"
											mountPath: "/var/log/" + _UXName
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
					name: _UXName
					namespace: "\(parameter.namespace)"
				}
				spec: {
					ports: [
						{
							port: _UXPort
							targetPort: _UXPort
						}
					]
					selector: app: _UXName
				}
			},
			// Ingress
			{
				apiVersion: "networking.k8s.io/v1"
				kind: "Ingress"
				metadata: {
					name: _UXName
					namespace: "\(parameter.namespace)"
				}
				spec: {
					ingressClassName: parameter.ingress.class
					rules: [
						{
							host: "\(_UXName).\(parameter.ingress.domain)"
							http: {
								paths: [
									{
										pathType: "Prefix"
										path: "/"
										backend: {
											service: {
												name: _UXName
												port: number: _UXPort
											}
										}
									}
									
								]
							}
						}
					]
					if parameter.ingress.tlsSecretName != "" {
						tls: [{
								hosts:["\(_UXName).\(parameter.ingress.domain)"]
								secretName: "\(parameter.ingress.tlsSecretName)"
						}]
					}
					
				}
					
			}
		]
	}
}
