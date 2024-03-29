package main

_ConfigReloaderName: "config-reloader"

_configReloader: {
	name: parameter.namePrefix + _ConfigReloaderName
	type: "helm"
	properties: {
		url: "\(parameter.helmURL)"
		chart: "reloader"
		releaseName: parameter.namePrefix + _ConfigReloaderName
		repoType: "helm"
		targetNamespace: "\(parameter.namespace)"
		version: "1.0.69"
		values: {
			global: imagePullSecrets: [
				{name: "\(parameter.imagePullSecret)"}
			]
			reloader: deployment: image: name: "\(parameter.registry)/stakater/reloader"
		}
	}
}
