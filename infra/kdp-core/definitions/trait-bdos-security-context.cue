"bdos-security-context": {
	annotations: {}
	attributes: {
		appliesToWorkloads: []
		podDisruptive: false
	}
	description: "Patch bdos-security-context for bdos application"
	labels: {}
	type: "trait"
}
template: {
	patch: {
		spec: template: spec: securityContext: {
			for k, v in parameter {
				"\(k)": v
			}
		}
	}
	parameter: {
		// +usage=Specify the UID to run the entrypoint of the container process.
		runAsUser?: int
		// +usage=Specify the GID to run the entrypoint of the container process.
		runAsGroup?: int
		// +usage=A special supplemental group that applies to all containers in a pod
		fsGroup?: int
	}
}
