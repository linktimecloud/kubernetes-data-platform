import "strings"

"bdos-ingress": {
	annotations: {}
	attributes: {
		appliesToWorkloads: []
		podDisruptive: false
	}
	description: "bdos-ingress for bdos application"
	labels: {}
	type: "trait"
}
template: {
	import ("strings")

	// declare _ingressName
	_ingressName: string
	if parameter.ingressName != _|_ {
		_ingressName: parameter.ingressName
	}
	if parameter.ingressName == _|_ {
		_ingressName: context.name + "-ingress"
	}
	outputs: "\(_ingressName)": {
		if parameter.rules != _|_ {
			apiVersion: "networking.k8s.io/v1"
			kind:       "Ingress"
			metadata: name: _ingressName
			if parameter.namespace != _|_ {
				metadata: namespace: parameter.namespace
			}
			if parameter.annotations != _|_ {
				metadata: annotations: {
					for k, v in parameter.annotations {
						"\(k)": v
					}
				}
			}

			if parameter.gateway != _|_ {
				metadata: annotations: {
					for k, v in parameter.gateway {
						"konghq.com/\(k)": v
					}
				}
			}

			_tlsList: [
				for v in parameter.tls {
					if v.tlsSecretName != _|_ && v.tlsSecretName != "" {
						_isTLS: true
					}
					if v.tlsSecretName == _|_ || v.tlsSecretName == "" {
						_isTLS: false
					}
					_tlshosts: [
						for i, tls_host in v.hosts {
							_tls_domain: *tls_host | string
							if strings.HasPrefix(tls_host, "http://") {
								_tls_domain: strings.TrimPrefix(tls_host, "http://")
							}
							if strings.HasPrefix(tls_host, "https://") {
								_tls_domain: strings.TrimPrefix(tls_host, "https://")
							}
							"\(i)": "\(_tls_domain)"
						},
					]
					hosts: [ for i, v in _tlshosts {v["\(i)"]}]
					secretName: v.tlsSecretName
				},
			]

			for v in _tlsList {
				if v._isTLS == true {
					spec: tls: [ for v in _tlsList if v._isTLS == true {v}]
				}
			}

			spec: {
				ingressClassName: parameter.ingressClassName
				rules: [
					for v in parameter.rules {
						_rule_domain: *v.host | string
						if strings.HasPrefix(v.host, "http://") {
							_rule_domain: strings.TrimPrefix(v.host, "http://")
						}
						if strings.HasPrefix(v.host, "https://") {
							_rule_domain: strings.TrimPrefix(v.host, "https://")
						}
						host: "\(_rule_domain)"
						http: paths: [
							for v_path in v.paths {
								path:     v_path.path
								pathType: "ImplementationSpecific"
								backend: service: {
									if v_path.serviceName != _|_ {
										name: v_path.serviceName
									}
									if v_path.serviceName == _|_ {
										name: context.name + "-svc"
									}
									port: number: v_path.servicePort
								}
							},
						]
					},
				]
			}

		}
	}

	// k8s service , if parameter.service is not empty
	if parameter.service != _|_ {
		svcspec: {
			type: parameter.service.type
			selector: {
				"app": context.name
			}
			ports: [ for v in parameter.service.ports {
				{
					name:       "port-\(strings.ToLower(v.protocol))-\(v.containerPort)"
					targetPort: v.containerPort
					port:       v.containerPort
					nodePort:   0
					protocol:   v.protocol
				}}]
			if parameter["sessionAffinity"] != _|_ {
				sessionAffinity: parameter.service.sessionAffinity.type
				if parameter.service.sessionAffinity.timeoutSeconds != _|_ {
					sessionAffinityConfig: clientIP: timeoutSeconds: parameter.service.sessionAffinity.timeoutSeconds
				}
			}
		}
		metaannotations: {
			if parameter.service.annotations != _|_ {
				for k, v in parameter.service.annotations {
					"\(k)": v
				}
			}
			// KongIngress CR
			if parameter.stickySession && parameter.ingressClassName == "kong"{
				"konghq.com/override": context.name + "-sticky-session"
			}
			// nginxIngress CR
		}
		metalabels: {
			"app": context.name
		}

		outputs: service: {
			apiVersion: "v1"
			kind:       "Service"
			metadata: {
				if parameter.service.serviceName != _|_ {
					name: parameter.service.serviceName
				}
				if parameter.service.serviceName == _|_ {
					name: context.name + "-svc"
				}
				if parameter.namespace != _|_ {
					namespace: parameter.namespace
				}
				labels: metalabels
			}
			metadata: annotations: metaannotations
			spec: svcspec
		}

	}

	
	outputs: {
		// KongIngress CR
		if parameter.stickySession && parameter.ingressClassName == "kong"{
			"kongIngress": {
				apiVersion: "configuration.konghq.com/v1"
				kind:       "KongIngress"
				metadata: {
					name: context.name + "-sticky-session"
					if parameter.namespace != _|_ {
						namespace: parameter.namespace
					}
				}
				upstream: {
					algorithm:      "consistent-hashing"
					hash_on:        "cookie"
					hash_on_cookie: context.name + "-sticky-session"
				}
			}
		}
		// nginxIngress CR
	}

	parameter: {
		namespace?:   *"default" | string
		ingressName?: string
		gateway?: [string]:     string
		annotations?: [string]: string
		ingressClassName: *"kong" | string
		stickySession:    *false | bool
		service?: {
			serviceName?: string
			annotations?: [string]: string
			// +usage=Specify the exposion ports
			ports?: [...{
				containerPort: int
				// +usage=Specify port protocol, options: "TCP","UDP"
				protocol:  "TCP" | "UDP"
				hostPort?: int
			}]
			// +usage=Specify what kind of Service you want. options: "ClusterIP","NodePort","LoadBalancer","ExternalName"
			type: *"ClusterIP" | "NodePort" | "LoadBalancer" | "ExternalName"
			// ++usage=Specify sessionAffinity configs
			sessionAffinity?: {
				type:            *"None" | string
				timeoutSeconds?: *10800 | int
			}
		}

		tls?: [...{
			// +usage=Specify the domain you want to expose
			hosts: [...string]
			// +usage=Specify the TLS secret of the domain
			tlsSecretName?: string
		}]
		rules?: [...{
			// +usage=Specify the domain you want to expose
			host: string
			// +usage=Specify the backend service
			paths: [...{
				// +usage=backend service path
				path: string
				// +usage=backend service name
				serviceName?: string
				// +usage=backend service port
				servicePort: int
			}]
		}]

	}
}
