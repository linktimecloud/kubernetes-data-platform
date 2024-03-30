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
	imagePullSecret: *"" | string
	// +usage=Specify namespace of the application to be installed
	namespace: *"kdp-system" | string
}
