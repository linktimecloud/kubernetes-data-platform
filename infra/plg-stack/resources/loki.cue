package main

_loki: {
    name: parameter.namePrefix + "loki"
    type: "helm"
    properties: {
        url: "\(parameter.helmURL)"
        repoType: "oci"
        chart: "loki"
        releaseName: parameter.namePrefix + "loki"
        targetNamespace: "\(parameter.namespace)"
        version: "5.43.5"
        values: {
            global: {
                image: registry: "\(parameter.registry)"
                dnsService: parameter.dnsService.name
                dnsNamespace: parameter.dnsService.namespace
            }
            imagePullSecrets: []
            loki: {
                auth_enabled: false
                limits_config: {
                    reject_old_samples: true
                    reject_old_samples_max_age: "168h"
                    max_cache_freshness_per_query: "10m"
                    split_queries_by_interval: "15m"
                }
                commonConfig: replication_factor: 1
                storage: {
                    type: "filesystem"
                }
            }
            singleBinary: {
                replicas: 1
                persistence: {
                    size: "20Gi"
                    storageClass: "\(parameter.storageConfig.storageClassMapping.localDisk)"
                }
            }
            monitoring: {
                dashboards: enabled: false
                serviceMonitor: labels: {
                    release: "prometheus"
                }
                selfMonitoring: enabled: false
                lokiCanary: enabled: false
            }
            test: enabled: false
            sidecar: rules: enabled: false
        }
    }
}

_promtail: {
    name: parameter.namePrefix + "promtail"
    type: "helm"
    properties: {
        url: "\(parameter.helmURL)"
        repoType: "oci"
        chart: "promtail"
        releaseName: parameter.namePrefix + "promtail"
        targetNamespace: "\(parameter.namespace)"
        version: "6.15.5"
        values: {
            global: {
                imageRegistry: "\(parameter.registry)"
                imagePullSecrets: []
            }
            serviceMonitor: {
                enabled: true
                labels: {
                    release: "prometheus"
                }
            }
            config: {
                snippets: {
                    extraLimitsConfig: """
                    max_streams: 0
                    """
                }
                file: """
                server:
                    log_level: {{ .Values.config.logLevel }}
                    log_format: {{ .Values.config.logFormat }}
                    http_listen_port: {{ .Values.config.serverPort }}
                    {{- with .Values.httpPathPrefix }}
                    http_path_prefix: {{ . }}
                    {{- end }}
                    {{- tpl .Values.config.snippets.extraServerConfigs . | nindent 2 }}

                clients:
                    {{- tpl (toYaml .Values.config.clients) . | nindent 2 }}

                positions:
                    {{- tpl (toYaml .Values.config.positions) . | nindent 2 }}

                scrape_configs:
                    {{- tpl .Values.config.snippets.scrapeConfigs . | nindent 2 }}
                    {{- tpl .Values.config.snippets.extraScrapeConfigs . | nindent 2 }}

                limits_config:
                    {{- tpl .Values.config.snippets.extraLimitsConfig . | nindent 2 }}

                target_config:
                    sync_period: "30s"

                tracing:
                    enabled: {{ .Values.config.enableTracing }}
                """
            }
        }
    }
}
