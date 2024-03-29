import (
	"strings"
	"strconv"
)

"kafka-manager": {
  annotations: {}
  labels: {}
  attributes: {
    "dynamicParameterMeta": [
			{
				"name": "dependencies.kafkaCluster",
				"type": "ContextSetting",
				"refType": "kafka",
				"refKey": "bootstrap_plain",
				"description": "kafka server list",
				"required": true
			},
			{
				"name": "dependencies.connect",
				"type": "ContextSetting",
				"refType": "connect",
				"refKey": "url",
				"description": "kafka connect url",
				"required": false
			},
			{
				"name": "dependencies.schemaRegistry",
				"type": "ContextSetting",
				"refType": "schema-registry",
				"refKey": "url",
				"description": "schema-registry hostname",
				"required": false
			}
		]
		apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "Application"
				type: "kafka-manager"
			}
		}
  }
  description: "kafka manager xdefinition"
  type: "xdefinition"
}

template: {
	output: {
		"apiVersion": "core.oam.dev/v1beta1",
		"kind": "Application",
		"metadata": {
			"name": context["name"],
			"namespace": context["namespace"]
		},
		"spec": {
			"components": [
				{
					"name": context["name"],
					"properties": {
						apiVersion: "apps/v1"
						kind:       "Deployment"
						metadata: {
							name:      context.name
							namespace: context.namespace
							labels: {
								"app": context.name
							}
						}
						spec: {
							replicas: parameter.replicas
							selector: matchLabels: {
								app:                     context.name
								"app.oam.dev/component": "kafka-manager"
							}
							template: {
								metadata: labels: {
									app:                     context.name
									"app.oam.dev/component": "kafka-manager"
								}
								spec: {
									containers: [{
										name: "kafka-manager"
										env: [
										{
											name:  "BOOTSTRAP_SERVERS"
											value: parameter.dependencies.kafkaCluster
										},
										if parameter.dependencies.schemaRegistry != _|_ {
										  {
											  name:  "SCHEMA_REGISTRY"
											  value: parameter.dependencies.schemaRegistry
										  },
										},
										if parameter.dependencies.connect != _|_ {
										  {
											  name:  "CONNECT"
											  value: parameter.dependencies.connect
										  }
										}
										]
										image: context.docker_registry+"/"+parameter.image
										livenessProbe: {
											failureThreshold: 3
											httpGet: {
												path:   "/health"
												port:   9061
												scheme: "HTTP"
											}
											initialDelaySeconds: 30
											periodSeconds:       20
											successThreshold:    1
											timeoutSeconds:      10
										}
										readinessProbe: {
											failureThreshold: 3
											httpGet: {
												path:   "/health"
												port:   9061
												scheme: "HTTP"
											}
											initialDelaySeconds: 30
											periodSeconds:       20
											successThreshold:    1
											timeoutSeconds:      10
										}
										resources: {
											limits: {
												cpu:    parameter.resources.limits.cpu
												memory: parameter.resources.limits.memory
											}
											requests: {
												cpu:    parameter.resources.requests.cpu
												memory: parameter.resources.requests.memory
											}
										}
										volumeMounts: [
												{
														name:      "logs"
														mountPath: "/logs/"
												}
										]
									}]
									volumes: [
										{
											name: "logs"
											emptyDir: {}
										}
									]
								}
							}
						}
					},
					"traits": [
						{
							"properties": {
								"rules": [
									{
										"host": context["name"]+"-"+context["namespace"]+"."+context["ingress.root_domain"],
										"paths": [
											{
												"path": "/",
												"serviceName": context["name"]+"-svc",
												"servicePort": 9060
											}
										]
									}
								],
								"tls": [
									{
										"hosts": [
											context["name"]+"-"+context["namespace"]+"."+context["ingress.root_domain"]
										],
										"tlsSecretName": context["ingress.tls_secret_name"]
									}
								]
							},
							"type": "bdos-ingress"
						}
					],
					"type": "raw"
				},
				{
					"name": context["name"]+"svc",
					"properties": {
						apiVersion: "v1"
						kind:       "Service"
						metadata: {
							name: context.name + "-svc"
							namespace: context.namespace
							labels: {
								"app": context.name
							}
						}
						spec: {
							type: "ClusterIP"
							selector: {
								"app": context.name
							}
							ports: [
								{
									name:       "port-tcp"
									targetPort: 9060
									port:       9060
									protocol:   "TCP"
								}
							]
						}
					}
					"type": "raw"
				},
				{
					"name": context.name + "-context"
					"type": "raw"
					"properties": {
						//生成connect地址端口相关的上下文信息
						"apiVersion": "bdc.kdp.io/v1alpha1",
						"kind": "ContextSetting",
						"metadata": {
								"name": context.namespace + "-" + context.name + "-context",
								"annotations": {
									"setting.ctx.bdc.kdp.io/type": "connect"
									"setting.ctx.bdc.kdp.io/origin": "system"
								}
						},
						"spec": {
							"name": context.name,
							"type": "kafka-manager",
							"properties": {
								"url": "https://"+context["name"]+"-"+context["namespace"]+"."+context["ingress.root_domain"]
							}
						}
					}
				}
			]
		}
	}
	parameter: {
    // +ui:order=1
	  // +ui:title=组件依赖
		dependencies: {
				// +ui:description=kafka manager依赖的kafka集群配置
				// +ui:order=2
				// +err:options={"required":"请先安装kafka，或添加kafka集群配置"}
				kafkaCluster: string
				// +ui:description=kafka manager依赖的kafka connect配置
				// +ui:order=3
				// +ui:options={"clearable":true}
				connect?: string
				// +ui:description=kafka manager依赖的schema registry配置
				// +ui:order=4
				// +ui:options={"clearable":true}
				schemaRegistry?: string
		}
		// +minimum=1
	  // +ui:description=副本数
    // +ui:order=2
		replicas: *1 | int
		// +ui:description=资源规格
		// +ui:order=3
		resources: {
			// +ui:description=预留
      // +ui:order=1
			requests: {
				// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
				// +ui:order=1
				// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
				cpu:  *"1" | string,
				// +pattern=^[1-9]\d*(Mi|Gi)$
				// +ui:order=2
				// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
				memory: *"1024Mi" | string
			},
			// +ui:description=限制
      // +ui:order=2
			limits: {
				// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
				// +ui:order=1
				// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
				cpu:  *"1" | string,
				// +pattern=^[1-9]\d*(Mi|Gi)$
				// +ui:order=2
				// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
				memory: *"1024Mi" | string
			}
		}
		// +ui:description=镜像版本
    // +ui:order=10001
	  // +ui:options={"disabled":true}
		image: *"v1.0.0-0.24.0" | string
	}
}