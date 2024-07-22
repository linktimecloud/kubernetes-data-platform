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
