REPOSITORY ?= openpolicyagent/gatekeeper-external-data-provider
IMG := $(REPOSITORY):dev

# When updating this, make sure to update the corresponding action in
# workflow.yaml
GOLANGCI_LINT_VERSION := v1.50.0

# Detects the location of the user golangci-lint cache.
GOLANGCI_LINT_CACHE := $(shell pwd)/.tmp/golangci-lint

.PHONY: build
build:
	go build -o bin/provider main.go

# lint runs a dockerized golangci-lint, and should give consistent results
# across systems.
# Source: https://golangci-lint.run/usage/install/#docker
.PHONY: lint
lint:
	docker run --rm -v $(shell pwd):/app \
		-v ${GOLANGCI_LINT_CACHE}:/root/.cache/golangci-lint \
		-w /app golangci/golangci-lint:${GOLANGCI_LINT_VERSION}-alpine \
		golangci-lint run -v

.PHONY: docker-buildx-builder
docker-buildx-builder:
	if ! docker buildx ls | grep -q container-builder; then\
		docker buildx create --name container-builder --use;\
	fi

.PHONY: docker-buildx
docker-buildx: docker-buildx-builder
	docker buildx build --load -t ${IMG} .

.PHONY: kind-load-image
kind-load-image:
	kind load docker-image ${IMG} --name gatekeeper
