"kustomize-patch": {
	attributes: {
		podDisruptive: false
	}
	description: "A list of StrategicMerge or JSON6902 patch to selected target"
	labels: {
		"ui-hidden": "true"
	}
	type: "trait"
	annotations: {
		"addon.oam.dev/ignore-without-component": "fluxcd-kustomize-controller"
  }
}

template: {
	patch: {
		spec: {
			patches: parameter.patches
		}
	}
	parameter: {
		// +usage=a list of StrategicMerge or JSON6902 patch to selected target
		patches: [...#patchItem]
	}

	// +usage=Contains a strategicMerge or JSON6902 patch
	#patchItem: {
		// +usage=Inline patch string, in yaml style
		patch: string
		// +usage=Specify the target the patch should be applied to
		target: #selector
	}

	// +usage=Selector specifies a set of resources
	#selector: {
		group?:              string
		version?:            string
		kind?:               string
		namespace?:          string
		name?:               string
		annotationSelector?: string
		labelSelector?:      string
	}
}
