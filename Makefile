IMAGE       ?= ghcr.io/ilnazziiazi/adguard-cli-docker
CLI_VERSION ?= 1.8.2
BUILD       ?= 1
TAG          = $(CLI_VERSION)-$(BUILD)

# gaia is amd64; the build host may not be.
build:
	docker buildx build --platform linux/amd64 --build-arg CLI_VERSION=$(CLI_VERSION) -t $(IMAGE):$(TAG) --load .

push:
	docker buildx build --platform linux/amd64 --build-arg CLI_VERSION=$(CLI_VERSION) -t $(IMAGE):$(TAG) --push .

.PHONY: build push
