##@ Build Dependencies Tools

# Setting SHELL to bash allows bash commands to be executed by recipes.
# Options are set to exit when a recipe line exits non-zero or a piped command fails.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif

## Location to install dependencies to
LOCALBIN ?= $(shell pwd)/bin
$(LOCALBIN):
	mkdir -p $(LOCALBIN)



GOLANG_CI_LINT_VERSION ?= v1.50.0
.PHONY: golang-ci
golang-ci:             ## Download Golang ci-lint locally if necessary.
ifneq ($(shell which golangci-lint),)
	@$(OK) "golangci-lint is already installed"
GOLANG_CI_LINT=$(shell which golangci-lint)
else ifeq (, $(shell which $(GOBIN)/golangci-lint))
	@{ \
	set -e ;\
	echo 'installing golangci-lint-$(GOLANG_CI_LINT_VERSION)' ;\
	curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(GOBIN) $(GOLANGCILINT_VERSION) ;\
	echo 'Successfully installed' ;\
	}
GOLANG_CI_LINT=$(GOBIN)/golangci-lint
else
	@$(OK) "golangci-lint is already installed"
GOLANG_CI_LINT=$(GOBIN)/golangci-lint
endif

.PHONY: golang-static-check
golang-static-check:          ## Download static-check locally if necessary.
ifeq (, $(shell which staticcheck))
	@{ \
	set -e ;\
	echo 'installing honnef.co/go/tools/cmd/staticcheck ' ;\
	go install honnef.co/go/tools/cmd/staticcheck@2023.1 ;\
	}
STATIC_CHECK=$(GOBIN)/staticcheck
else
STATIC_CHECK=$(shell which staticcheck)
endif

HELM_VERSION ?= helm-v3.6.0-linux-amd64.tar.gz
.PHONY: helm
helm: ## Download helm cli locally if necessary.
ifeq (, $(shell which helm))
	@{ \
	set -e ;\
	echo 'installing $(HELM_VERSION)' ;\
	wget $(ARTIFACTS_SERVER)/$(HELM_VERSION) ;\
	tar -zxvf $(HELM_VERSION) ;\
	mv linux-amd64/helm /bin/helm ;\
	rm -f $(HELM_VERSION) ;\
	rm -rf linux-amd64 ;\
	echo 'Successfully installed' ;\
    }
else
	@$(OK) Helm CLI is already installed
HELMBIN=$(shell which helm)
endif

.PHONY: helm-doc
helm-doc: ## Install helm-doc locally if necessary.
ifeq (, $(shell which readme-generator))
	@{ \
	set -e ;\
	echo 'installing readme-generator-for-helm' ;\
	npm install -g @bitnami/readme-generator-for-helm ;\
	}
else
	@$(OK) readme-generator-for-helm is already installed
HELM_DOC=$(shell which readme-generator)
endif


.PHONY: opm
OPM = ./bin/opm
opm: ## Download opm locally if necessary.
ifeq (,$(wildcard $(OPM)))
ifeq (,$(shell which opm 2>/dev/null))
	@{ \
	set -e ;\
	mkdir -p $(dir $(OPM)) ;\
	OS=$(shell go env GOOS) && ARCH=$(shell go env GOARCH) && \
	curl -sSLo $(OPM) https://github.com/operator-framework/operator-registry/releases/download/v1.23.0/$${OS}-$${ARCH}-opm ;\
	chmod +x $(OPM) ;\
	}
else
OPM = $(shell which opm)
endif
endif