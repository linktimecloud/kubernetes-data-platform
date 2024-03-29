"bdos-monitor": {
	annotations: {}
	attributes: podDisruptive: false
	description: "open monitoring index data for Prometheus to obtain(Depend on kube-prometheus-stack)."
	labels: {}
	type: "trait"
}

template: {
	outputs: "\(parameter.monitortype)-MonitorObject": {
		apiVersion: "monitoring.coreos.com/v1"
		metadata: {
			if parameter.namespace == _|_ {
				name: "\(context.namespace)-\(context.name)"
			}
			if parameter.namespace != _|_ {
				namespace: parameter.namespace
				name:      "\(parameter.namespace)-\(context.name)"
			}
		}
		if parameter.labels != _|_ {
			metadata: labels: {
				release: "prometheus"
				for k, v in parameter.labels {
					"\(k)": v
				}
			}
		}
		if parameter.labels == _|_ {
			metadata: labels: {
				app:     context.name
				release: "prometheus"
			}
		}
		if parameter.monitortype == "service" {
			kind: "ServiceMonitor"
			spec: {
				endpoints: [
					for v in parameter.endpoints {
						if v.portName != _|_ {
							port: v.portName
						}
						if v.portName == _|_ {
							port: "port-tcp-\(v.port)"
						}
						scheme:        v.scheme
						path:          v.path
						interval:      v.interval
						scrapeTimeout: v.scrape_timeout
						filterRunning: v.filterRunning
						if v.follow_redirects != _|_ {
							followRedirects: v.follow_redirects
						}
						if v.tlsConfig != _|_ {
							tlsConfig: {
								ca: {
									secret: v.tlsConfig.ca_secretKeyRef
								}
								cert: {
									secret: v.tlsConfig.cert_secretKeyRef
								}
								keySecret: v.tlsConfig.keySecret_secretKeyRef
							}
						}
						if v.path_params != _|_ {
							params: {
								for k1, v1 in v.path_params {
									"\(k1)": [
										for _, v2 in v1 {
											v2
										},
									]
								}
							}
						}
					},
				]
				if parameter.matchLabels != _|_ {
					selector: matchLabels: {
						for k, v in parameter.matchLabels {
							"\(k)": v
						}
					}
				}
				if parameter.matchLabels == _|_ {
					selector: matchLabels: app: context.name
				}
				if parameter.anyNamespace == true {
					namespaceSelector:
						any: true
				}
				if parameter.anyNamespace == false {
					if parameter.namespace == _|_ {
						// not found matchNames usage context.namespace
						if parameter.matchNames == _|_ {
							namespaceSelector:
								matchNames: [context.namespace]
						}
						if parameter.matchNames != _|_ {
							namespaceSelector: matchNames: [
								for _, v in parameter.matchNames {
									v
								},
							]
						}
					}
					if parameter.namespace != _|_ {
						namespaceSelector:
							matchNames: [parameter.namespace]
					}
				}
			}
		}

		if parameter.monitortype == "pod" {
			kind: "PodMonitor"
			spec: {
				podMetricsEndpoints: [
					for v in parameter.endpoints {
						port:          v.portName
						scheme:        v.scheme
						path:          v.path
						interval:      v.interval
						scrapeTimeout: v.scrape_timeout
						filterRunning: v.filterRunning
						if v.follow_redirects != _|_ {
							followRedirects: v.follow_redirects
						}
						if v.tlsConfig != _|_ {
							tlsConfig: {
								ca: {
									secret: v.tlsConfig.ca_secretKeyRef
								}
								cert: {
									secret: v.tlsConfig.cert_secretKeyRef
								}
								keySecret: v.tlsConfig.keySecret_secretKeyRef
							}
						}
						if v.path_params != _|_ {
							params: {
								for k1, v1 in v.path_params {
									"\(k1)": [
										for _, v2 in v1 {
											v2
										},
									]
								}
							}
						}
					},
				]
				if parameter.matchLabels != _|_ {
					selector: matchLabels: {
						for k, v in parameter.matchLabels {
							"\(k)": v
						}
					}
				}
				if parameter.matchLabels == _|_ {
					selector:
						matchLabels:
							app: context.name
				}
				if parameter.anyNamespace == true {
					namespaceSelector:
						any: true
				}
				if parameter.anyNamespace == false {
					if parameter.namespace == _|_ {
						// not found matchNames usage context.namespace
						if parameter.matchNames == _|_ {
							namespaceSelector:
								matchNames: [context.namespace]
						}
						if parameter.matchNames != _|_ {
							namespaceSelector: matchNames: [
								for _, v in parameter.matchNames {
									v
								},
							]
						}
					}
					if parameter.namespace != _|_ {
						namespaceSelector:
							matchNames: [parameter.namespace]
					}
				}
			}
		}
	}
	parameter: {
		namespace?: *"default" | string
		labels?: [string]: string
		// +usage=Select the monitoring indicator type, "service" / "pod" is optional, and "service" is the default
		monitortype: *"service" | "pod"
		// +usage=set endpoints to get metrics
		endpoints: [...{
			// +usage=HTTP path to scrape for metrics.
			path: *"/metrics" | string
			// +usage=the service port this endpoint refers to.
			port: int
			// +usage=Name of the service port this endpoint refers to.
			portName?: string
			// +usage=HTTP scheme to use for scraping.
			scheme: *"http" | string
			// +usage=https tls comes from secret.
			tlsConfig?: {
				ca_secretKeyRef: [string]:        string
				cert_secretKeyRef: [string]:      string
				keySecret_secretKeyRef: [string]: string
			}
			// +usage=Interval at which metrics should be scraped
			interval: *"30s" | string
			// +usage=Timeout after which the scrape is ended
			scrape_timeout: *"10s" | string
			// +usage=Optional HTTP URL parameters
			path_params?: [string]: [...string]
			// +usage=FollowRedirects configures whether scrape requests follow HTTP 3xx redirects.
			follow_redirects?: true | false
			// +usage=Drop pods that are not running. (Failed, Succeeded). Enabled by default.
			filterRunning: *true | false
		}]
		// +usage=find from namespace
		matchNames?: [...string]
		// +usage=find all namespace
		anyNamespace: *false | true
		// +usage=find from service with lable
		matchLabels?: [string]: string
	}
}
