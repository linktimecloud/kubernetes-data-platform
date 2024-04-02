package main

_mysqlService: {
	if parameter.mysqlArch != "replication" {
		[]
	}
	if parameter.mysqlArch == "replication" {
		[
			{
			    apiVersion: "v1"
				kind:       "Service"
				metadata: {
					name: parameter.namePrefix + "mysql"
					annotations: {
						"prometheus.io/port":   "9104"
						"prometheus.io/scrape": "true"
					}
					namespace: "\(parameter.namespace)"
				}
				spec: {
					ports: [{
						name:       "mysql"
						port:       3306
						protocol:   "TCP"
						targetPort: "mysql"
					}, {
						name:       "metrics"
						port:       9104
						protocol:   "TCP"
						targetPort: "metrics"
					}]
					selector: {
						"app.kubernetes.io/component": "primary"
						"app.kubernetes.io/instance":  parameter.namePrefix + "mysql"
						"app.kubernetes.io/name":      "mysql"
					}
					sessionAffinity: "None"
					type:            "ClusterIP"
				}
			}
		]
	}
}