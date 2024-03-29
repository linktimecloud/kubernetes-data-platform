include makefiles/const.mk
include makefiles/build.mk
include makefiles/dependency.mk

##@ General

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

##@ Test
## test: Run tests
test: cli-gen-test
	@$(OK) suite test pass

cli-gen-test: ## Run CLI tests
	go test $(shell go list ./...) -coverprofile coverage.out && go tool cover -func=coverage.out

.PHONY: lint
lint: golang-ci ## Run golangci-lint.
	@$(INFO) lint
	@$(GOLANG_CI_LINT) run --timeout 5m

.PHONY: vet
vet: ## Run go vet against code.
	@$(INFO) go vet
	@go vet $(shell go list ./...)

.PHONY: static-check
static-check: golang-static-check ## Run static-check.
	@$(INFO) staticcheck
	@$(STATIC_CHECK) $(shell go list ./...)
