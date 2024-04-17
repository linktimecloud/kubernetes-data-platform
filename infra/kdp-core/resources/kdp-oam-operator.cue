package main

_OperatorName: "kdp-oam-operator"
_APIServerName: "kdp-oam-operator-apiserver"
_APIServerPort: 8000

_kdpOAMOperator: {
	name: parameter.namePrefix + _OperatorName
	type: "helm"
	properties: {
		url:             "\(parameter.helmURL)"
		chart:           _OperatorName + "-chart"
		releaseName:     parameter.namePrefix + _OperatorName
		repoType:        "oci"
		targetNamespace: "\(parameter.namespace)"
		version:         "\(_version.operator)"
		values: {
			images: {
				registry: "\(parameter.registry)/linktimecloud"
				pullSecrets: [
					{name: "\(parameter.imagePullSecret)"},
				]
			}
			apiserver: {
				enabled: true
				extraArgs: [
					"--kube-api-qps=300",
					"--kube-api-burst=900"
				]
			}
			systemNamespace: name: "\(parameter.namespace)"
		}
	}
}
