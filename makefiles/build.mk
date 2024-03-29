
IMG			   ?= linktimecloud/kubernetes-data-platform:$(VERSION)
IMG_REGISTRY   ?= ""

##@ Build
.PHONY: docker-build
docker-build: docker-build-image  ## Build docker image
	@$(OK)

.PHONY: docker-build-image
docker-build-image:
	docker build -t $(IMG_REGISTRY)/$(IMG) -f Dockerfile .

.PHONY: docker-push
docker-push: docker-push-image  ## Push docker image to registry
	@$(OK)

.PHONY: docker-push-image
docker-push-image:
	docker push $(IMG_REGISTRY)/$(IMG)

.PHONY: kdp-cli-build
kdp-cli-build:  ## Build kdp CLI
	for os in darwin linux; do \
		for arch in amd64 arm64; do \
			env GOOS=$$os GOARCH=$$arch \
			go build -ldflags "-X kdp/cmd.CliVersion=$(VERSION) -X kdp/cmd.CliGoVersion=$(GO_VERSION) -X kdp/cmd.CliGitCommit=$(GIT_COMMIT) -X \"kdp/cmd.CliBuiltAt=$(BUILD_DATE)\" -X \"kdp/cmd.CliOSArch=$$os/$$arch\"" -o ./cmd/output/$(VERSION)/kdp-$$os-$$arch; \
		done \
	done

.PHONY: kdp-cli-push
kdp-cli-push:   ## Push kdp CLI to registry
	for file in ./cmd/output/$(VERSION)/kdp-*; do \
		curl --user $(SERVER_USER):$(SERVER_PASSWORD) -T $$file $(SERVER_URL)/kdp/$(VERSION)/$$(basename $$file); \
	done

.PHONY: kdp-cli-cleanip
kdp-cli-cleanup:   ## Clean up kdp CLI
	rm -rf ./cmd/output/$(VERSION)
