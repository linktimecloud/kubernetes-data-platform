##@ Docker image info
IMG			   ?= linktimecloud/kubernetes-data-platform:$(VERSION)
IMG_REGISTRY   ?= ""

##@ Build docker image
.PHONY: docker-build
docker-build: docker-build-image
	@$(OK)

.PHONY: docker-build-image
docker-build-image:
	docker build -t $(IMG_REGISTRY)/$(IMG) -f Dockerfile .

##@ Push docker image to registry
.PHONY: docker-push
docker-push: docker-push-image
	@$(OK)

.PHONY: docker-push-image
docker-push-image:
	docker push $(IMG_REGISTRY)/$(IMG)

##@ Build kdp CLI
.PHONY: kdp-cli-build
kdp-cli-build:
	for os in darwin linux; do \
		for arch in amd64 arm64; do \
			env GOOS=$$os GOARCH=$$arch \
			go build -ldflags "-X kdp/cmd.CliVersion=$(VERSION) -X kdp/cmd.CliGoVersion=$(GO_VERSION) -X kdp/cmd.CliGitCommit=$(GIT_COMMIT) -X \"kdp/cmd.CliBuiltAt=$(BUILD_DATE)\" -X \"kdp/cmd.CliOSArch=$$os/$$arch\"" -o ./cmd/output/$(VERSION)/kdp-$$os-$$arch; \
		done \
	done

##@ Push kdp CLI to registry
.PHONY: kdp-cli-push
kdp-cli-push:
	for file in ./cmd/output/$(VERSION)/kdp-*; do \
		curl --user $(SERVER_USER):$(SERVER_PASSWORD) -T $$file $(SERVER_URL)/kdp/$(VERSION)/$$(basename $$file); \
	done

##@ Clean up kdp CLI
.PHONY: kdp-cli-clean
kdp-cli-clean:
	rm -rf ./cmd/output/$(VERSION)
