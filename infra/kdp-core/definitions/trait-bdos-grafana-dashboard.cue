"bdos-grafana-dashboard": {
	annotations: {}
	attributes: podDisruptive: false
	description: "Import dashboards to Grafana(Depend on kube-prometheus-stack)."
	labels: {}
	type: "trait"
}

template: {
	outputs: GrafanaDashboardConfigmap: {
		if parameter.dashboard_data != _|_ {
			apiVersion: "v1"
			kind:       "ConfigMap"
			metadata: {
				name: context.name + "-dashboard"
				if parameter.namespace != _|_ {
					namespace: parameter.namespace
				}
			}
			metadata: labels: {
				grafana_dashboard: "1"
			}
			if parameter.labels != _|_ {
				metadata: labels: {
					for k, v in parameter.labels {
						"\(k)": v
					}
				}
			}
			if parameter.annotations != _|_ {
				metadata: annotations: {
					for k, v in parameter.annotations {
						"\(k)": v
					}
				}
			}
			if parameter.dashboard_data != _|_ {
				data: {
					for k, v in parameter.dashboard_data {
						"\(k)": v
					}
				}
			}

		}
	}
	// if parameter.dashboard_url != _|_ {
	//  outputs: ImportGrafanaDashboard: {
	//   apiVersion: "grafana.extension.oam.dev/v1alpha1"
	//   kind:       "ImportDashboard"
	//   spec: {
	//    grafana: {
	//     service:                   parameter.grafanaServiceName
	//     namespace:                 parameter.grafanaServiceNamespace
	//     credentialSecret:          parameter.credentialSecret
	//     credentialSecretNamespace: parameter.credentialSecretNamespace
	//    }
	//    urls: parameter.dashboard_url
	//   }
	//  }
	// }
	parameter: {
		namespace?: *"default" | string
		labels?: [string]:      string
		annotations?: [string]: string
		// +usage=Specify the grafana dashboard data
		dashboard_data?: [string]: string
		//                            dashboard_url?:             string
		//                            grafanaServiceName?:        string
		//                            grafanaServiceNamespace?:   *"default" | string
		//                            credentialSecret?:          string
		//                            credentialSecretNamespace?: *"default" | string
	}
}
