// parameter.cue is used to store addon parameters.
//
// You can use these parameters in template.cue or in resources/ by 'parameter.myparam'
//
// For example, you can use parameters to allow the user to customize
// container images, ports, and etc.
parameter: {
	// +usage=NamePrefix is a prefix appended to resources
	namePrefix: *"" | string
	// +usage=Specify the image repository that the KDP application use, e.g. bdos-docker-registry-svc
	registry: *"bdos-docker-registry-svc" | string
	// +usage=Specify the helm chart repository that the KDP application use, e.g. bdos-artifacts-svc
	helmURL: *"http://bdos-artifacts-svc/" | string
	// +usage=Specify image pull secret for your service
	imagePullSecret: *"devregistry" | string
	// +usage=Specify namespace of the application to be installed
	namespace: *"kdp-system" | string
	// +usage=Specify KDP version
	kdpVersion: *"v1.0.0" | string
	// +usage=Ingress settings
	ingress: {
		// +usage=Specify ingressClassName
		class: *"kong" | string
		// +usage=Specify the domain you want to expose
		domain: *"kdp.io" | string
		// +usage=Specify the TLS secret of the domain
		tlsSecretName: *"" | string
	}
	// +usage=Specify storage settings
	storageConfig: {
		// +usage=Storage class mapping
		storageClassMapping: {
			// +usage=The data is persisted to the worker node host
			localDisk: *"openebs-hostpath" | string
		}
	}
	// +usage=Specify MySQL common settings
	systemMysql: {
		// +usage=Specify mysql host
		host: *"mysql" | string
		// +usage=Specify mysql port
		port: *3306 | int
		// +usage=Specify mysql users authentication credentials
		users: {
			kdpAdmin: {
				user:     *"kdpAdmin" | string
				password: *"a2RwQWRtaW4xMjMq" | string
			}
		}
	}

	prometheus: externalUrl: *"" | string
	loki: externalUrl: *"" | string
	grafana: externalUrl: *"" | string
}
