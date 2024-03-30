"bdos-pdb": {
	type: "trait"
	annotations: {}
	description: "Create/Attach pdb on K8s pod"
	attributes: {
		podDisruptive: true
	}
}
template: {
	outputs: "\(context.name)-pdb": {
		apiVersion: "policy/v1beta1"
		kind:       "PodDisruptionBudget"
		metadata: {
			namespace: "\(context.namespace)"
			name:      "\(context.name)-pdb"
		}
		if parameter.namespace != _|_ {
				metadata: namespace: parameter.namespace
		}
		spec: {
			if parameter.maxUnavailable != _|_ {
				maxUnavailable: parameter.maxUnavailable
			}
			if parameter.maxUnavailable == _|_ {
				minAvailable: parameter.minAvailable
			}
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
		}
	}
	parameter: {
		minAvailable: *1 | int
		maxUnavailable?: *1 | int
		// +usage=find from service with lable
		matchLabels?: [string]: string
	}
}
