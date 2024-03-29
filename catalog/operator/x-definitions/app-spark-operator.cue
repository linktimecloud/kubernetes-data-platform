"spark-operator": {
	annotations: {}
	labels: {}
	attributes: {
		apiResource: {
			definition: {
				apiVersion: "bdc.kdp.io/v1alpha1"
				kind:       "Application"
				type:       "spark-operator"
			}
		}
	}
	description: "spark-operator xdefinition"
	type:        "xdefinition"
}

template: {
	output: {
		"apiVersion": "core.oam.dev/v1beta1"
		"kind":       "Application"
		"metadata": {
			"name":      context.name
			"namespace": context.namespace
		}
		"spec": {
			"components": [
				{
					"name": context.name
					"type": "helm"
					"properties": {
						"chart":           "spark-operator"
						"version":         parameter.chartVersion
						"url":             context.helm_repo_url
						"repoType":        "helm"
						"releaseName":     "spark-operator"
						"targetNamespace": context.namespace
						"values": {
							"image": {
								"repository": "\(context.docker_registry)/spark-operator/spark-operator"
								"tag":        parameter.imageTag
							}
							"resources":     parameter.resources
							"replicaCount":  parameter.replicas
							"batchScheduler": {
								"enable": parameter.volcano
							}
							"webhook": {
								"enable":         true
								"failOnError":    true
								"objectSelector": true
							}
							"leaderElection": {
								"lockName":      "\(context.namespace)-\(context.name)-lock"
								"lockNamespace": context.namespace
							}
							"metrics": {
								"enable": true
							}
							"affinity": {
								"podAntiAffinity": {
									"requiredDuringSchedulingIgnoredDuringExecution": [
										{
											"labelSelector": {
												"matchExpressions": [
													{
														"key":      "app.kubernetes.io/instance"
														"operator": "In"
														"values": [
															"spark-operator",
														]
													},
												]
											}
											"topologyKey": "kubernetes.io/hostname"
										},
									]
								}
							}
							"serviceAccounts": {
								"spark": {
									"create": true
									"name":   "spark-operator-spark"
								}
								"sparkoperator": {
									"create": true
									"name":   "spark-operator"
								}
							}
							"rbac": {
								"createRole":        true
								"createClusterRole": true
							}
						}
					}
					"traits": [
						{
							"type": "bdos-monitor"
							"properties": {
								"monitortype": "pod"
								"endpoints": [
									{
										"port":     10254
										"portName": "metrics"
										"path":     "/metrics"
									},
								]
								"matchLabels": {
									"app.kubernetes.io/name": "spark-operator"
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
												"alert":    "\(context.namespace)_spark_operator_job_fail"
												"expr":     "spark_app_failure_count > 3"
												"duration": "5m"
												"labels": {
													"severity": "warning"
													"channel":  "grafana_oncall"
												}
												"annotations": {
													"summary":     "too much spark job from spark operator submit failed."
													"description": "Found failure spark job: {{ $value }}"
												}
											},
										]
									},
								]
							}
						},
					]
				},
			]
		}
	}
	parameter: {
		// +ui:description=副本数
		// +ui:order=3
		// +minimum=1
		replicas: *2 | int
		// +ui:description=用 Volcano 调度 Spark pod
		// +ui:order=4
    // +ui:hidden=true
		volcano: *false | bool
		// +ui:description=资源
		// +ui:order=5
		resources: {
			// +ui:description=请求
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
				memory: *"64Mi" | string
			}
			// +ui:description=限制
			// +ui:order=2
			limits: {
				// +ui:description=CPU
				// +ui:order=1
				// +pattern=^(\d+\.\d{1,3}?|[1-9]\d*m?)$
				// +err:options={"pattern":"请输入正确的cpu格式，如1, 1000m"}
				cpu: *"1" | string
				// +ui:description=内存
				// +ui:order=2
				// +pattern=^[1-9]\d*(Mi|Gi)$
				// +err:options={"pattern":"请输入正确的内存格式，如1024Mi, 1Gi"}
				memory: *"512Mi" | string
			}
		}
		// +ui:description=Helm Chart 版本号
		// +ui:order=100
    // +ui:options={"disabled":true}
		chartVersion: *"v1.0.0-1.1.27" | string
		// +ui:description=镜像版本
		// +ui:order=101
    // +ui:options={"disabled":true}
		imageTag: *"v1.0.0-1.1.27" | string
	}
}
