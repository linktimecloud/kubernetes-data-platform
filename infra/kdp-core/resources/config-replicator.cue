package main

_ConfigReplicatorName: "config-replicator"

_configReplicator: {
	name: parameter.namePrefix + _ConfigReplicatorName
	type: "helm"
	properties: {
		url: "\(parameter.helmURL)"
		chart: "kubernetes-replicator"
		releaseName: parameter.namePrefix + _ConfigReplicatorName
		repoType: "helm"
		targetNamespace: "\(parameter.namespace)"
		version: "2.9.2"
		values: {
			image: {
				repository: "\(parameter.registry)/mittwald/kubernetes-replicator"
				pullPolicy: "IfNotPresent"
			}
			imagePullSecrets: [
				{name: "\(parameter.imagePullSecret)"}
			]
			args: [
				"-resync-period=1m"
			]
		}
	}
}
