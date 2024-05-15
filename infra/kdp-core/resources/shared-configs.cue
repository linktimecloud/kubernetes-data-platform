package main

import ("encoding/base64")

_sharedConfigs: {
    name: parameter.namePrefix + "shared-configs"
	type: "k8s-objects"
	properties: {
        objects: [
            {
                apiVersion: "v1"
                kind: "ConfigMap"
                metadata:{
                    name: "kdp-oam-operator-configmap"
                    namespace: parameter.namespace
                    labels: "kdp-operator-context": "KDP"
                }
                data: {
                    "K8S_IMAGE_PULL_SECRETS_NAME": parameter.imagePullSecret
                    "docker_registry": parameter.registry
                    "domain_suffix": "svc.cluster.local"
                    "helm_repo_url": parameter.helmURL
                    "storage_config.storage_class_mapping.local_disk": parameter.storageConfig.storageClassMapping.localDisk
                    "ingress.root_domain": parameter.ingress.domain
                    "ingress.tls_secret_name": parameter.ingress.tlsSecretName
                }
            },
            {
                apiVersion: "v1"
                kind: "ConfigMap"
                metadata: {
                    name: "promtail-conf"
                    namespace: "\(parameter.namespace)"
                    annotations: {
                        "replicator.v1.mittwald.de/replicate-to": "*"
                    }
                }
                data: {
                    "config.yaml": """
                    server:
                      http_listen_port: ${PROMTAIL_PORT:-3101}
                    positions:
                      filename: /tmp/positions.yaml
                    client:
                      url: \"${LOKI_PUSH_URL:-http://loki-gateway.\(parameter.namespace)/loki/api/v1/push}"
                    scrape_configs:
                      - job_name: \"${PROMTAIL_NAMESPACE}-${PROMTAIL_APPNAME}\"
                        static_configs:
                          - targets:
                              - localhost
                            labels:
                              log_sdk: \"${PROMTAIL_NAMESPACE}-${PROMTAIL_APPNAME}\"
                              namespace: \"${PROMTAIL_NAMESPACE}\"
                              pod: \"${POD_NAME}\"
                              app: \"${PROMTAIL_APPNAME}\"
                              job: \"${PROMTAIL_NAMESPACE}-${PROMTAIL_APPNAME}\"
                              stream: \"file\"
                              container: \"${PROMTAIL_APPNAME}\"
                              __path__: \"${PROMTAIL_LOG_PATH}/*\"
                    """
                }
            },
            {
                apiVersion: "v1"
                kind: "ConfigMap"
                metadata: {
                    name: "promtail-args"
                    namespace: "\(parameter.namespace)"
                    annotations: {
                        "replicator.v1.mittwald.de/replicate-to": "*"
                    }
                }
                data: {
                    if parameter.loki.externalUrl != "" {
                        LOKI_PUSH_URL: "\(parameter.loki.externalUrl)/loki/api/v1/push"
                        LOKI_ROOT_URL: "\(parameter.loki.externalUrl)"
                    }
                    if parameter.loki.externalUrl == "" || parameter.loki.externalUrl == _|_ {
                        LOKI_PUSH_URL: "http://loki-gateway.\(parameter.namespace)/loki/api/v1/push"
                        LOKI_ROOT_URL: "http://loki-gateway.\(parameter.namespace)"
                    }
                }
            },
            {
                apiVersion: "v1"
                kind: "ConfigMap"
                metadata: {
                    name: "mysql-setting"
                    namespace: "\(parameter.namespace)"
                }
                data: {
                    "MYSQL_HOST": "\(parameter.systemMysql.host)"
                    "MYSQL_PORT": "\(parameter.systemMysql.port)"
                }
            }
        ]
    }
}

_sharedSecrets: {
    name: parameter.namePrefix + "shared-secrets"
	type: "k8s-objects"
	properties: {
        objects: [
            {
                apiVersion: "v1"
                kind:       "Secret"
                metadata: {
                    name:      "mysql-secret"
                    namespace: "\(parameter.namespace)"
                }
                type: "Opaque"
                data: {
                    "MYSQL_PASSWORD": "\(parameter.systemMysql.users.kdpAdmin.password)"
                    "MYSQL_USER":     base64.Encode(null, "\(parameter.systemMysql.users.kdpAdmin.user)")
                }
            }
        ]
    }
}
