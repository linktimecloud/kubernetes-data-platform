##@ Docker image info
IMG			   ?= linktimecloud/kubernetes-data-platform:$(VERSION)
KDP_IMG        ?= linktimecloud/kdp:$(VERSION)
IMG_REGISTRY   ?= ""
OUTPUT_TYPE 	:= registry
TARGETARCHS 	:= amd64 arm64
ALL_OS_ARCH 	:= linux-arm64 linux-amd64

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


##@ Build infra image
.PHONY: kdp-infra-build
kdp-infra-build:
	CGO_ENABLED=0 GOOS=linux GOARCH=$(TARGETARCH) go build -ldflags "-X kdp/cmd.CliVersion=$(VERSION) -X kdp/cmd.CliGoVersion=$(GO_VERSION) -X kdp/cmd.CliGitCommit=$(GIT_COMMIT) -X \"kdp/cmd.CliBuiltAt=$(BUILD_DATE)\" -X \"kdp/cmd.CliOSArch=linux/$(TARGETARCH)\"" -o ./cmd/output/$(VERSION)/kdp-linux-$(TARGETARCH); \
	docker buildx build \
		--output=type=$(OUTPUT_TYPE) \
		--platform linux/$(TARGETARCH) \
		--provenance false \
		--build-arg VERSION=$(VERSION) \
		--build-arg TARGETARCH=$(TARGETARCH) \
		-t $(IMG_REGISTRY)/$(KDP_IMG)-linux-$(TARGETARCH) \
		-f kdp.Dockerfile .
	@$(OK)


##@ push infra image
.PHONY: publish
publish:
	docker manifest create --amend $(IMG_REGISTRY)/$(KDP_IMG) $(foreach osarch, $(ALL_OS_ARCH), $(IMG_REGISTRY)/$(KDP_IMG)-${osarch})
	docker manifest push --purge $(IMG_REGISTRY)/$(KDP_IMG)
	docker manifest inspect $(IMG_REGISTRY)/$(KDP_IMG)


##@ Build multi-arch image
.PHONY: multi-arch-builder
multi-arch-builder:
	for arch in $(TARGETARCHS); do \
		TARGETARCH=$${arch} $(MAKE) kdp-infra-build;\
    done
