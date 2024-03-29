kustomize: {
	attributes: workload: type: "autodetects.core.oam.dev"
	description: "kustomize can fetching, building, updating and applying Kustomize manifests from Git repo or Bucket or OCI repo."
	type:        "component"
	annotations: {
		"addon.oam.dev/ignore-without-component": "fluxcd-kustomize-controller"
	}
}

template: {
	output: {
		apiVersion: "kustomize.toolkit.fluxcd.io/v1beta2"
		kind:       "Kustomization"
		metadata: {
			name:      context.name
			namespace: context.namespace
		}
		spec: {
			interval: parameter.pullInterval
			sourceRef: {
				if parameter.repoType == "git" {
					kind: "GitRepository"
				}
				if parameter.repoType == "oss" {
					kind: "Bucket"
				}
				if parameter.repoType == "oci" {
					kind: "OCIRepository"
				}
				if parameter.sourceName == _|_ {
					name: context.name
				}
				if parameter.sourceName != _|_ {
					name: parameter.sourceName
				}
				namespace: context.namespace
			}
			path:    parameter.path
			suspend: parameter.suspend
			prune:   parameter.prune
			force:   parameter.force
			if parameter.targetNamespace != _|_ {
				targetNamespace: parameter.targetNamespace
			}
		}
	}

	outputs: {
		if parameter.sourceName == _|_ {
			repo: {
				apiVersion: "source.toolkit.fluxcd.io/v1beta2"
				metadata: {
					name:      context.name
					namespace: context.namespace
				}
				if parameter.repoType == "git" {
					kind: "GitRepository"
					spec: {
						url: parameter.url
						if parameter.git.branch != _|_ {
							ref: branch: parameter.git.branch
						}
						if parameter.git.provider != _|_ {
							if parameter.git.provider == "GitHub" {
								gitImplementation: "go-git"
							}
							if parameter.git.provider == "AzureDevOps" {
								gitImplementation: "libgit2"
							}
						}
						_secret
						_sourceCommonArgs
					}
				}
				if parameter.repoType == "oss" {
					kind: "Bucket"
					spec: {
						endpoint:   parameter.url
						bucketName: parameter.oss.bucketName
						provider:   parameter.oss.provider
						if parameter.oss.region != _|_ {
							region: parameter.oss.region
						}
						_secret
						_sourceCommonArgs
					}
				}
				if parameter.repoType == "oci" {
					kind: "OCIRepository"
					spec: {
						url: parameter.url
						if parameter.oci.provider != _|_ {
							provider: parameter.oci.provider
						}
						if parameter.oci.tag != _|_ {
							ref: tag: parameter.oci.tag
						}						
						_secret
						_sourceCommonArgs
					}
				}
			}
		}

		if parameter.imageRepository != _|_ {
			imageRepo: {
				apiVersion: "image.toolkit.fluxcd.io/v1beta1"
				kind:       "ImageRepository"
				metadata: {
					name:      context.name
					namespace: context.namespace
				}
				spec: {
					image:    parameter.imageRepository.image
					interval: parameter.imageRepository.interval
					if parameter.imageRepository.secretRef != _|_ {
						secretRef: name: parameter.imageRepository.secretRef
					}
				}
			}

			imagePolicy: {
				apiVersion: "image.toolkit.fluxcd.io/v1beta1"
				kind:       "ImagePolicy"
				metadata: {
					name:      context.name
					namespace: context.namespace
				}
				spec: {
					imageRepositoryRef: name: context.name
					policy: parameter.imageRepository.policy
					if parameter.imageRepository.filterTags != _|_ {
						filterTags: parameter.imageRepository.filterTags
					}
				}
			}

			imageUpdate: {
				apiVersion: "image.toolkit.fluxcd.io/v1beta1"
				kind:       "ImageUpdateAutomation"
				metadata: {
					name:      context.name
					namespace: context.namespace
				}
				spec: {
					interval: parameter.imageRepository.interval
					sourceRef: {
						kind: "GitRepository"
						if parameter.sourceName == _|_ {
							name: context.name
						}
						if parameter.sourceName != _|_ {
							name: parameter.sourceName
						}
					}
					git: {
						checkout: ref: branch: parameter.git.branch
						commit: {
							author: {
								email: "kubevelabot@users.noreply.github.com"
								name:  "kubevelabot"
							}
							if parameter.imageRepository.commitMessage != _|_ {
								messageTemplate: "Update image automatically.\n" + parameter.imageRepository.commitMessage
							}
							if parameter.imageRepository.commitMessage == _|_ {
								messageTemplate: "Update image automatically."
							}
						}
						push: branch: parameter.git.branch
					}
					update: {
						path:     parameter.path
						strategy: "Setters"
					}
				}
			}
		}
	}

	_secret: {
		if parameter.secretRef != _|_ {
			secretRef: {
				name: parameter.secretRef
			}
		}
	}

	_sourceCommonArgs: {
		interval: parameter.pullInterval
		if parameter.timeout != _|_ {
			timeout: parameter.timeout
		}
	}
	parameter: {
		repoType: *"git" | "oss" | "oci"
		// +usage=The image repository for automatically update image to git
		imageRepository?: {
			// +usage=The image url
			image: string
			// +usage=The name of the secret containing authentication credentials
			secretRef?: string
			// +usage=Policy gives the particulars of the policy to be followed in selecting the most recent image.
			policy: {
				// +usage=Alphabetical set of rules to use for alphabetical ordering of the tags.
				alphabetical?: {
					// +usage=Order specifies the sorting order of the tags.
					// +usage=Given the letters of the alphabet as tags, ascending order would select Z, and descending order would select A.
					order?: "asc" | "desc"
				}
				// +usage=Numerical set of rules to use for numerical ordering of the tags.
				numerical?: {
					// +usage=Order specifies the sorting order of the tags.
					// +usage=Given the integer values from 0 to 9 as tags, ascending order would select 9, and descending order would select 0.
					order: "asc" | "desc"
				}
				// +usage=SemVer gives a semantic version range to check against the tags available.
				semver?: {
					// +usage=Range gives a semver range for the image tag; the highest version within the range that's a tag yields the latest image.
					range: string
				}
			}
			// +usage=FilterTags enables filtering for only a subset of tags based on a set of rules. If no rules are provided, all the tags from the repository will be ordered and compared.
			filterTags?: {
				// +usage=Extract allows a capture group to be extracted from the specified regular expression pattern, useful before tag evaluation.
				extract?: string
				// +usage=Pattern specifies a regular expression pattern used to filter for image tags.
				pattern?: string
			}
			// +usage=The image url
			commitMessage?: string
			// +uasge=Interval is the length of time to wait between scans of the image repository.
			interval: *"5m" | string
		}
		// +usage=The interval at which to check for repository/bucket and release updates, default to 5m
		pullInterval: *"5m" | string
		// +usage=The Git or Helm repository URL, OSS endpoint or OCI repo, accept HTTP/S or SSH address as git url
		url: string
		// +usage=The name of the secret containing authentication credentials
		secretRef?: string
		// +usage=The timeout for operations like download index/clone repository, optional
		timeout?: string
		// +usage=The name of the source already existed
		sourceName?: string

		git?: {
			// +usage=The Git reference to checkout and monitor for changes, defaults to master branch
			branch: string
			// +usage=Determines which git client library to use. Defaults to GitHub, it will pick go-git. AzureDevOps will pick libgit2.
			provider?: *"GitHub" | "AzureDevOps"
		}
		oss?: {
			// +usage=The bucket's name, required if repoType is oss
			bucketName: string
			// +usage="generic" for Minio, Amazon S3, Google Cloud Storage, Alibaba Cloud OSS, "aws" for retrieve credentials from the EC2 service when credentials not specified, default "generic"
			provider: *"generic" | "aws"
			// +usage=The bucket region, optional
			region?: string
		}
		oci?: {		   
			// +usage=The OIDC provider used for authentication purposes.The generic provider can be used for public repositories or when static credentials are used for authentication, either with spec.secretRef or spec.serviceAccountName
			provider: *"generic" | "azure" | "aws" | "gcp"
			// +usage=The image tag
			tag: *"latest" | string
			
		}
		//+usage=Path to the directory containing the kustomization.yaml file, or the set of plain YAMLs a kustomization.yaml should be generated for.
		path: string
		//+usage=Whether to delete objects that have already been applyed
		prune: *true | bool
		//+usage=This flag tells the controller to suspend subsequent kustomize executions, it does not apply to already started executions. Defaults to false.
		suspend: *false | bool
		//+usage=Force instructs the controller to recreate resources when patching fails due to an immutable field change.
		force: *false | bool
		//+usage=TargetNamespace sets or overrides the namespace in the kustomization.yaml file, optional
		targetNamespace?: string
	}
}
