"bdos-pod-affinity": {
	annotations: {}
	attributes: {
		appliesToWorkloads: []
		podDisruptive: false
	}
	description: "Patch bdos-pod-affinity for bdos application"
	labels: {}
	type: "trait"
}
template: {
	patch: spec: template: spec: {
		if parameter.affinity != _|_ {
			affinity: {
				podAffinity: {
					requiredDuringSchedulingIgnoredDuringExecution:
					[
						{
							labelSelector: {
								matchExpressions: [
									for k, v in parameter.affinity {
										key:      k
										operator: "In"
										values:   v
									},
								]
							}
							if parameter.topologyKey != _|_ {
								topologyKey: parameter.topologyKey
							}
						},
					]
				}
			}
		}
		if parameter.antiAffinity != _|_ {
			affinity: {
				podAntiAffinity: {
					requiredDuringSchedulingIgnoredDuringExecution:
					[
						{
							labelSelector: {
								matchExpressions: [
									for k, v in parameter.antiAffinity {
										key:      k
										operator: "In"
										values:   v
									},
								]
							}
							if parameter.topologyKey != _|_ {
								topologyKey: parameter.topologyKey
							}
						},
					]
				}
			}
		}
	}
	parameter: {
		affinity?: [string]: [...string]
		antiAffinity?: [string]: [...string]
		topologyKey?: *"kubernetes.io/hostname" | string
	}
}
