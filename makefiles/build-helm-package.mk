##@ Helm package
HELM_CHART         ?= kdp-infra
HELM_CHART_VERSION ?= $(VERSION)
KUBESPHERE_EXTENSION ?= helm
KUBESPHERE_EXTENSION_VERSION   ?= $(KUBESPHERE_EXTENSION_VERSION)

.PHONY: helm-package
helm-package:   ## Helm package
	cd helm/charts && $(HELMBIN) package $(HELM_CHART) --version $(HELM_CHART_VERSION) --app-version $(HELM_CHART_VERSION)


.PHONY: kubesphere-helm-package
kubesphere-helm-package:   ## Kubesphere Helm package
	$(KSBUILDBIN) package $(KUBESPHERE_EXTENSION)


.PHONY: helm-doc
helm-doc:   ## Helm doc
	cd helm/charts && $(HELMBIN) docs $(HELM_CHART)


.PHONY: helm-doc-gen
helm-doc-gen: helm-doc  ## helm-doc-gen: Generate helm chart README.md
	readme-generator -v helm/charts/$(HELM_CHART)/values.yaml -r helm/charts/$(HELM_CHART)/README.md