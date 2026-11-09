# make build PROFILE=motion | make build-all verify-all | make push PROFILE=full REGISTRY=... IMAGE_OWNER=...
PROFILE ?= basic
PROFILES = $(basename $(notdir $(wildcard profiles/*.conf)))
export REGISTRY IMAGE_OWNER IMAGE_NAME

.PHONY: list discover-packages build build-all verify verify-all push

list:
	@scripts/list-profiles.sh

discover-packages:
	@scripts/discover-packages.sh

build:
	scripts/build.sh $(PROFILE)

build-all:
	@set -e; for f in $(PROFILES); do scripts/build.sh $$f; done

verify:
	scripts/verify-no-secrets.sh $$(scripts/build.sh $(PROFILE) --print-tags | head -n1)

verify-all:
	@set -e; for f in $(PROFILES); do $(MAKE) -s verify PROFILE=$$f; done

push:
	scripts/build.sh $(PROFILE) --push
