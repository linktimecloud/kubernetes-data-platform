// parameter.cue is used to store addon parameters.
//
// You can use these parameters in template.cue or in resources/ by 'parameter.myparam'
//
// For example, you can use parameters to allow the user to customize
// container images, ports, and etc.
parameter: {
	// +usage=NamePrefix is a prefix appended to resources
	namePrefix: *"" | string
	// +usage=Specify the image registry that the KDP application use
	registry: *"registry-cr.linktimecloud.com" | string
	// +usage=Specify the helm repository that the KDP application use
	helmURL: *"oci://registry-cr.linktimecloud.com/linktimecloud" | string
	// +usage=Specify image pull secret for your service
	imagePullSecret: *"cr-secret" | string
	// +usage=Specify namespace of the application to be installed
	namespace: *"kdp-system" | string
	// +usage=Ingress settings
	ingress: {
		// +usage=Specify ingressClassName
		class: *"kong" | string
		// +usage=Specify the domain you want to expose
		domain: *"kdp-e2e.io" | string
		// +usage=Specify the TLS secret of the domain
		tlsSecretName: *"" | string
	}
	// +usage=Specify the storage settings
	storageConfig: {
		// +usage=Storage class mapping
		storageClassMapping: {
			// +usage=The data is persisted to the worker node host
			localDisk: *"openebs-hostpath" | string
			// +usage=The data is persisted to the NFS node host
			nfs: *"kadalu.storage-path" | string
		}
		volumeClaimTemplate: {
			accessModes: *"ReadWriteMany" | string
		}
	}
	// +usage=Specify cluster DNS service
	dnsService: {
		name: *"coredns" | string
		namespace: *"kube-system" | string
	}
	// +usage=Enable/Disable Prometheus CRD installation
	prometheusCRD: enabled: *true | bool
	// +usage=Enable/Disable Prometheus default rules installation
	prometheusDefaultRules: enabled: *true | bool
	// +usage=Enable/Disable Prometheus/AlertManager installation
	prometheus: {
		enabled: *true | bool
		externalUrl: *"" | string
	}
	// +usage=Enable/Disable Grafana installation
	grafana: enabled: *true | bool
	// +usage=Enable/Disable Loki/Prometheus installation
	loki: enabled: *true | bool
}
