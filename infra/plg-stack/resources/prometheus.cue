package main

_prometheus: {
	name: parameter.namePrefix + "prometheus"
	type: "helm"
	properties: {
		url:             "\(parameter.helmURL)"
		chart:           "kube-prometheus-stack"
		version: 		 "56.21.1"
		releaseName:     parameter.namePrefix + "prometheus"
		repoType:        "oci"
		targetNamespace: "\(parameter.namespace)"
		values: {
			fullnameOverride: parameter.namePrefix + "kps"
			defaultRules: {
				if parameter.prometheusDefaultRules.enabled != true {
					create: false
				}
				if parameter.prometheusDefaultRules.enabled == true {
					create: true
					rules: {
						windows: false
					}
				}
				labels: {
					prometheus: "k8s"
					role: "alert-rules"
				}
				additionalRuleLabels: {
					prometheus: "k8s"
					role: "alert-rules"
				}
			}
			global: {
				imageRegistry: "\(parameter.registry)"
				imagePullSecrets: [{
					name: "\(parameter.imagePullSecret)"
				}]
			}
			crds: {
				if parameter.prometheusCRD.enabled != true {
					enabled: false
				}
			}
			alertmanager: {
				if parameter.prometheus.enabled != true {
					enabled: false
				}
				config: {
					global: {
						resolve_timeout:    "5m"
						http_config: {
							tls_config: {
								insecure_skip_verify: true
							}
						}
					}
					route: {
						group_by:					["alertname"]
						group_wait:				"30s"
						group_interval:		"5m"
						repeat_interval:	"12h"
					}
					templates: ["/etc/alertmanager/config/*.tmpl"]
				}
				alertmanagerSpec: {
					image: registry: "\(parameter.registry)"
					logFormat: "logfmt"
					logLevel: "info"
					replicas: 1
					retention: "120h"
					storage: {
						volumeClaimTemplate: {
							spec: {
								accessModes: ["ReadWriteOnce"]
								storageClassName: "\(parameter.storageConfig.storageClassMapping.localDisk)"
								resources: requests: storage: "100Mi"
							}
						}
					}
				}
				ingress: {
					enabled: true
					ingressClassName: parameter.ingress.class
					hosts: ["alertmanager.\(parameter.ingress.domain)",]
					path: ["/"]
					if parameter.ingress.tlsSecretName != "" {
						tls: [{
							secretName: "\(parameter.ingress.tlsSecretName)"
							hosts: ["alertmanager.\(parameter.ingress.domain)",]
						}]
					}
				}
			}
			grafana: {
				if parameter.grafana.enabled != true {
					enabled: false
				}
				additionalDataSources: [{
					name:      "Loki"
					url:       "http://loki:3100"
					type:      "loki"
					access:    "proxy"
					editable:  true
					isDefault: false
					jsonData: {
						tlsSkipVerify:	true
						timeInterval:	"30s"
					}
				}]
				defaultDashboardsEnabled:  true
				defaultDashboardsTimezone: "utc+08:00"
				image: registry: "\(parameter.registry)"
				initChownData: image: registry: "\(parameter.registry)"
				ingress: {
					enabled: true
					ingressClassName: parameter.ingress.class
					hosts: ["grafana.\(parameter.ingress.domain)",]
					path: "/"
					if parameter.ingress.tlsSecretName != "" {
						tls: [{
							secretName: "\(parameter.ingress.tlsSecretName)"
							hosts: ["grafana.\(parameter.ingress.domain)",]
						}]
					}
				}
				"grafana.ini": {
					analytics: {
						enabled: false
					}
					auth: {
						disable_login_form: true
						disable_signout_menu: true
					}
					"auth.anonymous": {
						enabled: true
						org_role: "Admin"
					}
					"auth.basic": {
						enabled: true
					}
					help: {
						enabled: false
					}
					news: {
						news_feed_enabled: false
					}
					users: {
						default_language: "detect"
					}
				}
				persistence: {
					enabled: 			true
					type:    			"pvc"
					accessModes: 		["ReadWriteOnce"]
					storageClassName: 	"\(parameter.storageConfig.storageClassMapping.localDisk)"
					size:             	"10Gi"
					finalizers:			["kubernetes.io/pvc-protection"]
				}
				serviceMonitor: {
					enabled: true
					path:    "/metrics"
					labels: {
						release: parameter.namePrefix + "prometheus"
					}
				}
				sidecar: {
					dashboards: {
						enabled: true
						label: "grafana_dashboard"
						labelValue: "1"
						searchNamespace: "ALL"
						multicluster: {
							global: {
								enabled: false
							}
							etcd: {
								enabled: false
							}
						}
						provider: {
							allowUiUpdates: true
						}
					}
					datasources: {
						enabled: true
						defaultDatasourceEnabled: true
						isDefaultDatasource: true
						uid: "prometheus"
						url: "http://kps-prometheus:9090/"
						label: "grafana_datasource"
						labelValue: "1"
						alertmanager: {
							enabled: true
							uid: "alertmanager"
						}
					}
				}
			}
			prometheusOperator: {
				if parameter.prometheus.enabled != true {
					enabled: false
				}
				image: registry: "\(parameter.registry)"
				admissionWebhooks: patch: image: registry: "\(parameter.registry)"
				prometheusDefaultBaseImageRegistry: "\(parameter.registry)"
				alertmanagerDefaultBaseImageRegistry: "\(parameter.registry)"
				prometheusConfigReloader: image: registry: "\(parameter.registry)"
				thanosImage: image: registry: "\(parameter.registry)"
			}
			prometheus: {
				if parameter.prometheus.enabled != true {
					enabled: false
				}
				ingress: {
					enabled: true
					ingressClassName: parameter.ingress.class
					hosts: ["prometheus.\(parameter.ingress.domain)",]
					path: ["/"]
					if parameter.ingress.tlsSecretName != "" {
						tls: [{
							secretName: "\(parameter.ingress.tlsSecretName)"
							hosts: ["prometheus.\(parameter.ingress.domain)",]
						}]
					}
				}
				prometheusSpec: {
					replicas: 1
					shards:   1
					image: registry: "\(parameter.registry)"
					retention: "7d"
					retentionSize: "20GiB"
					logFormat: "logfmt"
					logLevel: "info"
					podAntiAffinity: "soft"
					storageSpec: {
						volumeClaimTemplate: {
							spec: {
								accessModes: ["ReadWriteOnce"]
								storageClassName: "\(parameter.storageConfig.storageClassMapping.localDisk)"
								resources: {
									requests: {
										storage: "20Gi"
									}
								}
							}
						}
					}
				}
			}
			kubeStateMetrics: {
				if parameter.prometheus.enabled != true {
					enabled: false
				}
			}
			kubeProxy: {
				if parameter.prometheus.enabled != true {
					enabled: false
				}
			}
			"kube-state-metrics": image: registry: "\(parameter.registry)"
			nodeExporter: {
				if parameter.prometheus.enabled != true {
					enabled: false
				}
			}
			"prometheus-node-exporter": image: registry: "\(parameter.registry)"
		}
	}
}
