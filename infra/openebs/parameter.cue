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
}
