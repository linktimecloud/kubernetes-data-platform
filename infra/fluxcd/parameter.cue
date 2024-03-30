parameter: {
	//+usage=Base URL for images that the FluxCD controllers use, e.g. ghcr.io
	registry?: string
	//+usage=Deploy to specified clusters. Leave empty to deploy to all clusters.
	clusters?: [...string]
	//+usage=Namespace to deploy to, defaults to flux-system
	namespace: *"kdp-system" | string
	//+usage=OnlyHelmComponents only enable helm associated components, default to false
	onlyHelmComponents: *false | bool
	//+usage=advanced options for Helm Controller
	helmControllerOptions?: [...string]
	//+usage=advanced options for Source Controller
	sourceControllerOptions?: [...string]
	//+usage=advanced options for Kustomize Controller
	kustomizeControllerOptions?: [...string]
	//+usage=advanced options for Image Reflector Controller
	imageReflectorControllerOptions?: [...string]
	//+usage=advanced options for Image Automation Controller
	imageAutomationControllerOptions?: [...string]
}