helm: {
	attributes: {
		workload: type: "autodetects.core.oam.dev"
		status: {
			healthPolicy: #"""
				isHealth: len(context.output.status.conditions) != 0 && context.output.status.conditions[0]["status"]=="True"
				"""#
			customStatus: #"""
					repoMessage:    *"" | string
					releaseMessage: *"Wating repository ready" | string
					if context.outputs.repo == _|_ {
						repoMessage: "Use existed repository"
					}
					if context.outputs.repo != _|_ && context.outputs.repo.status == _|_ {
						repoMessage:    "Fetching repository"
					}
					if context.outputs.repo != _|_ && context.outputs.repo.status != _|_ && context.outputs.repo.status.conditions != _|_ {
						repoStatus: context.outputs.repo.status
						if len(repoStatus.conditions) == 0 || repoStatus.conditions[0]["type"] != "Ready" {
							repoMessage: "Fetch repository fail"
						}
						if len(repoStatus.conditions) != 0 && repoStatus.conditions[0]["type"] == "Ready" {
							repoMessage: "Fetch repository successfully"
						}
					}
					if context.output.status == _|_ {
							releaseMessage: "Creating helm release"
					}
					if context.output.status != _|_ {
							releaseStatus: context.output.status
							if releaseStatus.conditions != _|_ {
								if len(releaseStatus.conditions) > 0 {
									if releaseStatus.conditions[0]["message"] != _|_ {
										if releaseStatus.conditions[0]["message"] == "Release reconciliation succeeded" {
											releaseMessage: "Create helm release successfully"
										}
										if releaseStatus.conditions[0]["message"] != "Release reconciliation succeeded" {
												releaseBasicMessage: "Delivery helm release in progress, message: " + releaseStatus.conditions[0]["message"]
												if len(releaseStatus.conditions) == 1 {
													releaseMessage: releaseBasicMessage
												}
												if len(releaseStatus.conditions) > 1 {
													if releaseStatus.conditions[1]["message"] != _|_ {
														releaseMessage: releaseBasicMessage + ", " + releaseStatus.conditions[1]["message"]
													}
												}
										}
									}
								}
							}
					}
					message: repoMessage + ", " + releaseMessage
				"""#
		}
	}
	description: "helm release is a group of K8s resources from either git repository or helm repo"
	type:        "component"
}

template: {
	outputs: {
		if parameter.sourceName == _|_ {
			repo: {
				apiVersion: "source.toolkit.fluxcd.io/v1beta2"
				metadata: {
					name: context.name
				}
				if parameter.repoType == "git" {
					kind: "GitRepository"
					spec: {
						url: parameter.url
						if parameter.git.branch != _|_ {
							ref: branch: parameter.git.branch
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
				if parameter.repoType == "helm" || parameter.repoType == "oci" {
					kind: "HelmRepository"
					spec: {
						url: parameter.url
						if parameter.repoType == "oci" {
							type: "oci"
						}
						if parameter.helmrepository.provider != _|_ {
							provider: parameter.helmrepository.provider
						}
						_secret
						_sourceCommonArgs
					}
				}
			}
		}
	}
	output: {
		apiVersion: "helm.toolkit.fluxcd.io/v2beta1"
		kind:       "HelmRelease"
		metadata: {
			name: context.name
		}
		spec: {
			timeout:  parameter.installTimeout
			interval: parameter.pullInterval
			chart: {
				spec: {
					chart:   parameter.chart
					version: parameter.version
					sourceRef: {
						if parameter.repoType == "git" {
							kind: "GitRepository"
						}
						if parameter.repoType == "helm" || parameter.repoType == "oci" {
							kind: "HelmRepository"
						}
						if parameter.repoType == "oss" {
							kind: "Bucket"
						}
						if parameter.sourceName == _|_ {
							name: context.name
						}
						if parameter.sourceName != _|_ {
							name: parameter.sourceName
						}
					}
					interval: parameter.interval
					if parameter["valuesFiles"] != _|_ {
						valuesFiles: parameter["valuesFiles"]
					}
				}
			}
			if parameter.targetNamespace != _|_ {
				targetNamespace: parameter.targetNamespace
			}
			if parameter.releaseName != _|_ {
				releaseName: parameter.releaseName
			}
			if parameter.values != _|_ {
				values: parameter.values
			}
			if parameter.valuesFrom != _|_ {
				valuesFrom: [for v in parameter.valuesFrom {{
					kind: v.kind
					name: v.name
					if v.valuesKey != _|_ {
						valuesKey: v.valuesKey
					}
					if v.targetPath != _|_ {
						targetPath: v.targetPath
					}
					if v.optional != _|_ {
						optional: v.optional
					}
				}}]
			}
			install: {
				remediation: {
					retries: parameter.retries
				}
			}
			upgrade: {
				remediation: {
					retries: parameter.retries
				}
				if parameter.upgradeCRD != _|_ {
					if parameter.upgradeCRD {
						 crds: "CreateReplace"
					}
				}
			}
		}
	}

	_secret: {
		if parameter.secretRef != _|_ {
			if parameter.secretRef != "" {
				secretRef: {
					name: parameter.secretRef
				}
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
		repoType: *"helm" | "git" | "oss" | "oci"
		// +usage=The interval at which to check for repository/bucket and release updates, default to 5m
		pullInterval: *"5m" | string
		// +usage=The  Interval at which to reconcile the Helm release, default to 30s
		interval: *"30s" | string
		// +usage=The Git or Helm repository URL, OSS endpoint, accept HTTP/S or SSH address as git url,
		url: string
		// +usage=The name of the secret containing authentication credentials
		secretRef?: string
		// +usage=The timeout for operations like download index/clone repository, optional
		timeout?: string
		// +usage=The timeout for operation `helm install`, optional
		installTimeout: *"10m" | string
		// +usage=The name of the source already existed
		sourceName?: string

		git?: {
			// +usage=The Git reference to checkout and monitor for changes, defaults to main branch
			branch: *"main" | string
		}
		oss?: {
			// +usage=The bucket's name, required if repoType is oss
			bucketName: string
			// +usage="generic" for Minio, Amazon S3, Google Cloud Storage, Alibaba Cloud OSS, "aws" for retrieve credentials from the EC2 service when credentials not specified, default "generic"
			provider: *"generic" | "azure" | "aws" | "gcp"
			// +usage=The bucket region, optional
			region?: string
		}
		helmrepository?: {		   
			// +usage=The OIDC provider used for authentication purposes.The generic provider can be used for public repositories or when static credentials are used for authentication, either with spec.secretRef or spec.serviceAccountName
			provider: *"generic" | "azure" | "aws" | "gcp"		
			
		}
		// +usage=Alternative list of values files to use as the chart values (values.yaml is not included by default), expected to be a relative path in the SourceRef.Values files are merged in the order of this list with the last file overriding the first.
		valuesFiles?: [...string]

		// +usage=1.The relative path to helm chart for git/oss source. 2. chart name for helm resource 3. relative path for chart package(e.g. ./charts/podinfo-1.2.3.tgz)
		chart: string
		// +usage=Chart version
		version: *"*" | string
		// +usage=The namespace for helm chart, optional
		targetNamespace?: string
		// +usage=The release name
		releaseName?: string
		// +usage=Retry times when install/upgrade fail.
		retries: *3 | int
		// +usage=Chart values
		values?: #nestedmap
		// +usage=valuesFrom holds references to resources containing Helm values for this HelmRelease, and information about how they should be merged.
		valuesFrom?: [...{
			// +usage=Kind of the values referent, valid values are ('Secret', 'ConfigMap').
			kind: "Secret" | "ConfigMap"
			// +usage=Name of the values referent. Should reside in the same namespace as the referring resource.
			name: string
			// +usage=ValuesKey is the data key where the values.yaml or a specific value can be found at. Defaults to 'values.yaml'.
			valuesKey?: string
			// +usage=TargetPath is the YAML dot notation path the value should be merged at. When set, the ValuesKey is expected to be a single flat value. Defaults to 'None', which results in the values getting merged at the root.
			targetPath?: string
			// +usage=Optional marks this ValuesReference as optional. When set, a not found error or the values reference is ignored, but any ValuesKey, TargetPath or transient error will still result in a reconciliation failure.
			optional?: bool
		}]
		upgradeCRD?: *false | bool
	}

	#nestedmap: {
		...
	}
}
