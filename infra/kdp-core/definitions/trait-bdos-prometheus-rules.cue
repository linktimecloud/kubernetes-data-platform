"bdos-prometheus-rules": {
	annotations: {}
	attributes: podDisruptive: false
	description: "Scrape exporter metrcis to prometheus(Depend on kube-prometheus-stack)."
	labels: {}
	type: "trait"
}

template: {
	outputs: PrometheusRule: {
		apiVersion: "monitoring.coreos.com/v1"
		kind:       "PrometheusRule"
		metadata: {
			name: context.name + "-prom-rule"
			if parameter.namespace != _|_ {
				namespace: parameter.namespace
			}
		}
		if parameter.labels != _|_ {
			metadata: labels: {
				prometheus: "k8s"
				role:       "alert-rules"
				release:    "prometheus"
				for k, v in parameter.labels {
					"\(k)": v
				}
			}
		}
		if parameter.labels == _|_ {
			metadata: labels: {
				prometheus: "k8s"
				role:       "alert-rules"
				release:    "prometheus"
			}
		}
		if parameter.annotations != _|_ {
			metadata: annotations: {
				for k, v in parameter.annotations {
					"\(k)": v
				}
			}
		}
		spec: groups: [
			for v in parameter.groups {
				name: v.name
				rules: [
					for v_rule in v.rules {
						alert: v_rule.alert
						expr:  v_rule.expr
						"for": v_rule.duration
						labels: {
							for k, v in v_rule.labels {
								"\(k)": v
							}
						}
						annotations: {
							for k, v in v_rule.annotations {
								"\(k)": v
							}
						}
					},
				]
			},
		]

	}
	parameter: {
		namespace?: *"default" | string
		labels?: [string]:      string
		annotations?: [string]: string
		// +usage=Specify the prometheus group rules
		groups?: [...{
			// +usage=Specify the rule group name
			name: string
			// +usage=Specify the rules info
			rules: [...{
				alert:    string
				expr:     string
				duration: string
				labels: [string]:      string
				annotations: [string]: string
			}]
		}]
	}
}
