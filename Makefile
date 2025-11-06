# Set the base name for the image
IMAGE_NAME:=codice/ddf-base

GIT_SHA:=$(shell git rev-parse HEAD)
MASTER_SHA:=$(shell git show-ref -s refs/heads/master)
IMAGE_VERSION=3.0

# Multi-architecture configuration
PLATFORMS:=linux/amd64,linux/arm64
BUILDER_NAME:=ddf-multiarch

# Compute Build Tags
BUILD_TAG=$(IMAGE_NAME):$(IMAGE_VERSION)
LATEST_TAG=$(IMAGE_NAME):latest

.DEFAULT_GOAL := help

.PHONY: help
help: ## Display help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: info
info: ## Show build information (versions, tags, platforms)
	@echo "Image Name:     $(IMAGE_NAME)"
	@echo "Version:        $(IMAGE_VERSION)"
	@echo "Build Tag:      $(BUILD_TAG)"
	@echo "Latest Tag:     $(LATEST_TAG)"
	@echo "Platforms:      $(PLATFORMS)"
	@echo "Builder:        $(BUILDER_NAME)"
	@echo "Git SHA:        $(GIT_SHA)"

.PHONY: setup-buildx
setup-buildx: ## Set up Docker Buildx builder (first time only)
	@echo "Setting up Docker Buildx builder: $(BUILDER_NAME)"
	@if ! docker buildx ls | grep -q $(BUILDER_NAME); then \
		docker buildx create --name $(BUILDER_NAME) --use --bootstrap; \
		echo "Builder $(BUILDER_NAME) created and activated"; \
	else \
		docker buildx use $(BUILDER_NAME); \
		echo "Builder $(BUILDER_NAME) already exists, activated"; \
	fi

.PHONY: image
image: ## Build the docker image for current architecture
	@echo "Building $(BUILD_TAG) for current architecture"
	@docker build --pull -t $(BUILD_TAG) -t $(LATEST_TAG) .

.PHONY: dev-build
dev-build: image ## Alias for 'image' target

.PHONY: image-multiarch
image-multiarch: setup-buildx ## Build multi-arch images locally (stores in build cache)
	@echo "Building $(BUILD_TAG) for $(PLATFORMS)"
	@docker buildx build \
		--platform $(PLATFORMS) \
		--pull \
		-t $(BUILD_TAG) \
		-t $(LATEST_TAG) \
		.
	@echo "Multi-arch build complete (stored in build cache)"

.PHONY: push
push: image ## Push single-architecture docker image
	@echo "Pushing $(BUILD_TAG)"
	@docker push $(BUILD_TAG)
	@docker push $(LATEST_TAG)

.PHONY: push-multiarch
push-multiarch: setup-buildx ## Build and push multi-arch images to registry
	@echo "Building and pushing $(BUILD_TAG) for $(PLATFORMS)"
	@docker buildx build \
		--platform $(PLATFORMS) \
		--pull \
		-t $(BUILD_TAG) \
		-t $(LATEST_TAG) \
		--push \
		.
	@echo "Multi-arch images pushed successfully"

.PHONY: test-amd64
test-amd64: ## Test AMD64 architecture build
	@echo "Testing AMD64 build..."
	@docker run --rm --platform linux/amd64 $(BUILD_TAG) /bin/bash -c "props version && jq --version"
	@echo "AMD64 test passed"

.PHONY: test-arm64
test-arm64: ## Test ARM64 architecture build
	@echo "Testing ARM64 build..."
	@docker run --rm --platform linux/arm64 $(BUILD_TAG) /bin/bash -c "props version && jq --version"
	@echo "ARM64 test passed"

.PHONY: test-all
test-all: image-multiarch test-amd64 test-arm64 ## Build and test both architectures

.PHONY: inspect
inspect: ## Inspect multi-arch manifest
	@echo "Inspecting manifest for $(BUILD_TAG)"
	@docker buildx imagetools inspect $(BUILD_TAG)

.PHONY: clean
clean: ## Clean up build resources
	@echo "Cleaning up build resources..."
	@docker buildx prune -f
	@echo "Cleanup complete"

.PHONY: clean-builder
clean-builder: ## Remove buildx builder
	@echo "Removing builder $(BUILDER_NAME)"
	@docker buildx rm $(BUILDER_NAME) || true
	@echo "Builder removed"

