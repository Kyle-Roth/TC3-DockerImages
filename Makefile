# make build FLAVOR=motion | make build-all verify-all | make push FLAVOR=all REGISTRY=... IMAGE_OWNER=...
FLAVOR ?= basic
FLAVORS = $(basename $(notdir $(wildcard flavors/*.conf)))
export REGISTRY IMAGE_OWNER IMAGE_NAME

.PHONY: list discover-packages build build-all verify verify-all push

list:
	@scripts/list-flavors.sh

discover-packages:
	@scripts/discover-packages.sh

build:
	scripts/build.sh $(FLAVOR)

build-all:
	@set -e; for f in $(FLAVORS); do scripts/build.sh $$f; done

verify:
	scripts/verify-no-secrets.sh $$(scripts/build.sh $(FLAVOR) --print-tags | head -n1)

verify-all:
	@set -e; for f in $(FLAVORS); do $(MAKE) -s verify FLAVOR=$$f; done

push:
	scripts/build.sh $(FLAVOR) --push
