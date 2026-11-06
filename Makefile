# TwinCAT 3.1 XAR RT Linux images
#
#   make build-image FLAVOR=motion
#   make build-all
#   make push-image FLAVOR=all REGISTRY=git.example.com IMAGE_OWNER=myorg
#
# Variables are exported to scripts/*.sh (see scripts/build.sh for details).

FLAVOR        ?= basic
REGISTRY      ?=
IMAGE_OWNER   ?=
IMAGE_NAME    ?= tc31-xar
LATEST_FLAVOR ?= all
# Credentials: BHF_USER/BHF_PASSWORD from the environment or .env (see .env.example).
# APT_AUTH_CONF=<netrc file> is used only when those are not set.

export REGISTRY IMAGE_OWNER IMAGE_NAME LATEST_FLAVOR

FLAVORS = $(basename $(notdir $(wildcard flavors/*.conf)))
IMAGE   = $(shell scripts/build.sh $(FLAVOR) --print-tags | head -n1)

.DEFAULT_GOAL := help
.PHONY: help list-flavors discover-packages build-image build-all verify-image verify-all \
        push-image push-all run-containers restart-containers list-containers \
        stop-and-remove-containers container-logs

list-flavors: ## List flavors and their packages
	@scripts/list-flavors.sh

discover-packages: ## List TwinCAT packages available in the Beckhoff repo
	@scripts/discover-packages.sh

build-image: ## Build FLAVOR for the host platform and load it locally
	scripts/build.sh $(FLAVOR)

build-all: ## Build every flavor locally
	@set -e; for f in $(FLAVORS); do scripts/build.sh $$f; done

verify-image: ## Scan the local FLAVOR image for leaked credentials
	scripts/verify-no-secrets.sh $(IMAGE)

verify-all: ## Scan every local flavor image for leaked credentials
	@set -e; for f in $(FLAVORS); do scripts/verify-no-secrets.sh $$(scripts/build.sh $$f --print-tags | head -n1); done

push-image: ## Build FLAVOR multi-arch and push to REGISTRY (docker login first)
	scripts/build.sh $(FLAVOR) --push

push-all: ## Build and push every flavor
	@set -e; for f in $(FLAVORS); do scripts/build.sh $$f --push; done

run-containers: ## Start containers using Docker Compose
	docker compose up -d

restart-containers: ## Restart containers using Docker Compose
	docker compose down
	docker compose up -d

list-containers: ## List containers managed by Docker Compose
	docker compose ps -a

stop-and-remove-containers: ## Stop and remove containers managed by Docker Compose
	docker compose down

container-logs: ## Follow container logs
	docker compose logs -ft

help: ## Show this help
	@echo "Usage: make <target> [FLAVOR=<flavor>]   flavors: $(FLAVORS)"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{ printf "  %-28s %s\n", $$1, $$2 }'
