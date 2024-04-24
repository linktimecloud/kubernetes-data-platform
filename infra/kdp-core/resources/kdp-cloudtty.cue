package main

_CloudTtyName: "cloudtty"

_kdpCloudTty: {
	name: parameter.namePrefix + _CloudTtyName
	type: "helm"
	properties: {
		url:             "\(parameter.helmURL)"
		chart:           _CloudTtyName
		releaseName:     parameter.namePrefix + _CloudTtyName
		repoType:        "oci"
		version:         "0.5.7"
		values: {
			global: {
				imageRegistry: "\(parameter.registry)"
				imagePullSecrets: [
					{name: "\(parameter.imagePullSecret)"},
				]
			}
			replicaCount: 1
		}
	}
}

_kdpTerminalConfigTask: {
	name: parameter.namePrefix +"terminal-config-task"
	type: "k8s-objects"
	properties: {
		objects: [
				{
					apiVersion: "batch/v1"
					kind: "Job"
					metadata: {
						name: parameter.namePrefix + "init-kubeconfig"
					}
					spec: {
						ttlSecondsAfterFinished: 60
						template: {
							spec: {
								volumes: [
										{
											name: "template"
											projected: {
												defaultMode: 420
												sources: [
													{
														configMap: {
															name: "kubeconfig-template"
															items: [
																{
																	key: "kubeconfig-template"
																	path: "kubeconfig-template"
																},
																{
																	key: "kubeconfig-secret-template"
																	path: "kubeconfig-secret-template"
																},
																{
																	key: "create-kubeconfig"
																	path: "create-kubeconfig.sh"
																}
															]
														}
													}
												]
											}
										}
									]
								containers: [
									{
										name: "init-kubeconfig"
										image: "\(parameter.registry)/cloudtty/cloudshell:v0.5.7"
										imagePullPolicy: "IfNotPresent"
										volumeMounts: [
											{
												name: "template"
												mountPath: "/opt"
											}
										]
										command: [
											"bash",
											"-c",
											"cd /tmp;cp /opt/* ./;sh create-kubeconfig.sh"
										]

									}
								]
								serviceAccount: "cloudtty-controller-manager"
								restartPolicy: "OnFailure"
							}
						}
					}
				}
		]
	}
}


_KdpTerminalConfig: {
	name: parameter.namePrefix +"terminal-config"
	type: "k8s-objects"
	properties: {
		objects: [
			{
				apiVersion: "v1"
				kind: "ServiceAccount"
				metadata: {
					name: "pod-terminal-sa"
					namespace: "\(parameter.namespace)"
				}
			},
			{
				apiVersion: "v1"
				kind: "Secret"
				metadata: {
					name: "pod-terminal-token"
					namespace: "\(parameter.namespace)"
					annotations: {
						"kubernetes.io/service-account.name": "pod-terminal-sa"
					}
				}
				type: "kubernetes.io/service-account-token"
			},
			{
				apiVersion: "v1"
				kind: "ServiceAccount"
				metadata: {
					name: "general-terminal-sa"
					namespace: "\(parameter.namespace)"
				}
			},
			{
				apiVersion: "v1"
				kind: "Secret"
				metadata: {
					name: "general-terminal-token"
					namespace: "\(parameter.namespace)"
					annotations: {
						"kubernetes.io/service-account.name": "general-terminal-sa"
					}
				}
				type: "kubernetes.io/service-account-token"
			},
			{
				kind: "ClusterRole"
				apiVersion: "rbac.authorization.k8s.io/v1"
				metadata: {
					name: "pod-terminal-cr"
				}
				rules: [{
					apiGroups: [""]
					resources: [
						"pods",
						"pods/exec",
						"pods/log",
					]
					verbs: [
						"get",
						"list",
						"exec",
						"logs",
						"create"
					]
				}]
			},
			{
				kind: "ClusterRole"
				apiVersion: "rbac.authorization.k8s.io/v1"
				metadata: {
					name: "general-terminal-cr"
				}
				rules: [
					{
						apiGroups: [""]
						resources: [
							"pods",
							"pods/log",
							"pods/exec"
						]
						verbs: [
							"get",
							"list",
							"create",
							"update",
							"delete"
						]
					},
					{
						apiGroups: [""]
						resources: [
							"services",
							"configmaps",
							"secrets",
							"persistentvolumes",
							"persistentvolumeclaims",
							"endpoints",
							"events",
							"limitranges",
							"resourcequotas",
							"componentstatuses"
						]
						verbs: [
							"get",
							"list",
							"watch",
							"create",
							"update",
							"patch",
							"delete"
						]
					},
					{
						apiGroups: ["apps"]
						resources: [
							"deployments",
							"replicasets",
							"statefulsets",
							"daemonsets"
						]
						verbs: [
							"get",
							"list",
							"watch",
							"create",
							"update",
							"patch",
							"delete"
						]
					},
					{
						apiGroups: ["batch"]
						resources: [
							"jobs",
							"cronjobs"
						]
						verbs: [
							"get",
							"list",
							"watch",
							"create",
							"update",
							"patch",
							"delete"
						]
					},
					{
						apiGroups: [
							"extensions"
						]
						resources: [
							"ingresses"
						]
						verbs: [
							"get",
							"list",
							"watch",
							"create",
							"update",
							"patch",
							"delete"
						]
					},
					{
						apiGroups: ["bdc.kdp.io"]
						resources: [
							"applications"
						]
						verbs: [
							"get",
							"list",
							"create",
							"update",
							"delete",
						]
					},
					{
						apiGroups: [
							"bdc.kdp.io"
						]
						resources: [
							"bigdataclusters",
							"contextsecrets",
							"contextsettings",
							"xdefinitions",
						]
						verbs: [
							"get",
							"list"
						]
					},
					{
						apiGroups: ["cloudshell.cloudtty.io"]
						resources: [
							"cloudshells"
						]
						verbs: [
							"get",
							"list",
						]
					},

				]
			},
			{
				kind: "ClusterRoleBinding"
				apiVersion: "rbac.authorization.k8s.io/v1"
				metadata: {
					name: "pod-terminal-crb"
				}
				subjects: [
					{
						kind: "ServiceAccount"
						name: "pod-terminal-sa"
						namespace: "\(parameter.namespace)"
					}
				]
				roleRef: {
					apiGroup: "rbac.authorization.k8s.io"
					kind: "ClusterRole"
					name: "pod-terminal-cr"
				}
			},
			{
				kind: "ClusterRoleBinding"
				apiVersion: "rbac.authorization.k8s.io/v1"
				metadata: {
					name: "general-terminal-crb"
				}
				subjects: [
					{
						kind: "ServiceAccount"
						name: "general-terminal-sa"
						namespace: "\(parameter.namespace)"
					}
				]
				roleRef: {
					apiGroup: "rbac.authorization.k8s.io"
					kind: "ClusterRole"
					name: "general-terminal-cr"
				}
			},
			{
				apiVersion: "v1"
				kind: "ConfigMap"
				metadata: {
					name: "kubeconfig-template"
				}
				data: {
					"kubeconfig-template": """
					apiVersion: v1
					kind: Config
					users:
					- name: USER
					  user:
					    token: TOKEN_DECODE
					clusters:
					- cluster:
					    certificate-authority-data: CLUSTER_AUTH
					    server: KUBE_APISERVER
					  name: USER-cluster
					contexts:
					- context:
					      cluster: USER-cluster
					      user: USER
					  name: USER-cluster
					current-context: USER-cluster
					"""
					"kubeconfig-secret-template": """
					kind: Secret
					apiVersion: v1
					metadata:
					  name: SECRECT_NAME
					  namespace: \(parameter.namespace)
					data:
					  config: SECRECT_DATA
					"""
					"create-kubeconfig": """
					KUBE_APISERVER='https://kubernetes.default.svc';
					for i in pod-terminal general-terminal;do
							TOKEN_DECODE=$(kubectl get secret/$i-token -n \(parameter.namespace) -o jsonpath='{.data.token}'| base64 -d)
							CLUSTER_AUTH=$(kubectl get secret/$i-token -n \(parameter.namespace) -o yaml |grep ca.crt |awk '{print $2}')
							# cat kubeconfig-template |sed "s#USER#$i#g" |sed "s#KUBE_APISERVER#$KUBE_APISERVER#g" |sed "s#CLUSTER_AUTH#$CLUSTER_AUTH#g" |sed "s#TOKEN_DECODE#$TOKEN_DECODE#g" >$i.config
							KUBE_BASE_CODE=$(cat kubeconfig-template |sed "s#USER#$i#g" |sed "s#KUBE_APISERVER#$KUBE_APISERVER#g" |sed "s#CLUSTER_AUTH#$CLUSTER_AUTH#g" |sed "s#TOKEN_DECODE#$TOKEN_DECODE#g"|base64 -w 0)
							cat kubeconfig-secret-template |sed "s#SECRECT_NAME#$i-secret#g" |sed "s#SECRECT_DATA#$KUBE_BASE_CODE#g" >$i.yaml
							kubectl apply -f $i.yaml
					done
					"""
				}
			}
		]
	}
}


_kdpTerminalIngress: {
	name: parameter.namePrefix +"terminal-ingress"
	type: "k8s-objects"
	properties: {
		objects: [
			{
				apiVersion: "networking.k8s.io/v1"
				kind: "Ingress"
				metadata: {
					name: "cloudtty-ingress"
					namespace: "\(parameter.namespace)"
					annotations: {
						"konghq.com/strip-path": "true"
					}
				}
				spec: {
					ingressClassName: parameter.ingress.class
					rules: [
						{
							host: "cloudtty.\(parameter.ingress.domain)"
							http: {
								paths: [
									{
										path: "/template"
										pathType: "Prefix"
										backend: {
											service: {
												name: "template"
												port: {
													number: 7681
												}
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