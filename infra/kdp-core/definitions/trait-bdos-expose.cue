"bdos-expose": {
	annotations: {}
	attributes: podDisruptive: false
	description: "Expose port to enable web traffic for your component."
	labels: {}
	type: "trait"
}

template: {
	import ("strings")
	svcspec: {
		type: parameter.type
		selector: {
			"app": context.name
		}
		ports: [ for v in parameter.ports {
			{
				name:       "port-\(strings.ToLower(v.protocol))-\(v.containerPort)"
				targetPort: v.containerPort
				port:       v.containerPort
				nodePort:   0
				protocol:   v.protocol
			}}]
		if parameter["sessionAffinity"] != _|_ {
			sessionAffinity: parameter.sessionAffinity.type
			if parameter.sessionAffinity.timeoutSeconds != _|_ {
				sessionAffinityConfig: clientIP: timeoutSeconds: parameter.sessionAffinity.timeoutSeconds
			}
		}
	}
	metaannotations: {
		if parameter.annotations != _|_ {
			for k, v in parameter.annotations {
				"\(k)": v
			}
		}
	}
	metalabels: {
		"app": context.name
	}
	outputs: service: {
		apiVersion: "v1"
		kind:       "Service"
		metadata: {
			if parameter.serviceName != _|_ {
				name: parameter.serviceName
			}
			if parameter.serviceName == _|_ {
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
	outputs: {
		if parameter.headless {
			"headless": {
				apiVersion: "v1"
				kind:       "Service"
				metadata: {
					if parameter.serviceName != _|_ {
						name: parameter.serviceName
					}
					if parameter.serviceName == _|_ {
						name: context.name + "-headless"
					}
					if parameter.namespace != _|_ {
						namespace: parameter.namespace
					}
					labels: metalabels
				}
				metadata: annotations: metaannotations
				spec: svcspec
				spec: clusterIP: "None"
			}
		}
	}


	parameter: {
		namespace?:   *"default" | string
		serviceName?: string
		annotations?: [string]: string
		// +usage=Specify the exposion ports
		ports?: [...{
			containerPort: int
			// +usage=Specify port protocol, options: "TCP","UDP"
			protocol:  "TCP" | "UDP"
			hostPort?: int
		}]
		headless: *false | bool
		// +usage=Specify what kind of Service you want. options: "ClusterIP","NodePort","LoadBalancer","ExternalName"
		type: *"ClusterIP" | "NodePort" | "LoadBalancer" | "ExternalName"
		// ++usage=Specify sessionAffinity configs
		sessionAffinity?: {
			type:            *"None" | string
			timeoutSeconds?: *10800 | int
		}
	}
}
