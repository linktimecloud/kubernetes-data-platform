##@ Helm package
HELM_CHART         ?= kdp-infra
HELM_CHART_VERSION ?= $(VERSION)

.PHONY: helm-package
helm-package:   ## Helm package
	$(HELMBIN) package $(HELM_CHART) --version $(HELM_CHART_VERSION) --app-version $(HELM_CHART_VERSION)



.PHONY: helm-doc-gen
helm-doc-gen: helm-doc  ## helm-doc-gen: Generate helm chart README.md
	readme-generator -v kdp-infra/values.yaml -r kdp-infra/README.md