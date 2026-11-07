#!/bin/sh
# Build one flavor.
#   scripts/build.sh <flavor>               host platform, loaded into local docker
#   scripts/build.sh <flavor> --push        all PLATFORMS, pushed to $REGISTRY/$IMAGE_OWNER
#   scripts/build.sh <flavor> --print-tags  print the image tags and exit
# Env: REGISTRY, IMAGE_OWNER, IMAGE_NAME (default tc31-xar), BUILD_REF (default git HEAD),
#      CHANNEL: release (default) tags <flavor>, <flavor>-YYYYMMDD and, for full, latest;
#               dev tags <flavor>-dev and <flavor>-<sha>
set -eu
. "$(dirname -- "$0")/lib.sh"

load_flavor "${1:?usage: $0 <flavor> [--push|--print-tags]}"
mode=${2:-}

ref=${BUILD_REF:-$(git -C "$REPO_ROOT" rev-parse HEAD)}
image=$(echo "${REGISTRY:+$REGISTRY/}${IMAGE_OWNER:+$IMAGE_OWNER/}${IMAGE_NAME:-tc31-xar}" | tr '[:upper:]' '[:lower:]')
case ${CHANNEL:-release} in
    release)
        tags="$image:$FLAVOR $image:$FLAVOR-$(date -u +%Y%m%d)"
        [ "$FLAVOR" = full ] && tags="$tags $image:latest" ;;
    dev) tags="$image:$FLAVOR-dev $image:$FLAVOR-$(printf '%.7s' "$ref")" ;;
    *) die "unknown CHANNEL '$CHANNEL' (release|dev)" ;;
esac

case $mode in
    --print-tags) printf '%s\n' $tags; exit 0 ;;
    --push) platforms=$PLATFORMS output=--push ;;
    "") platforms=linux/$(docker version --format '{{.Server.Arch}}') output=--load ;;
    *) die "unknown option: $mode" ;;
esac

require_auth
echo ">>> $FLAVOR [$platforms]: $PACKAGES"
# shellcheck disable=SC2046
docker buildx build "$REPO_ROOT/docker" \
    --secret "id=apt,src=$AUTH_FILE" \
    --platform "$platforms" \
    --build-arg "FLAVOR=$FLAVOR" \
    --build-arg "TC_PACKAGES=$PACKAGES" \
    --provenance=false \
    $(printf -- '--tag %s ' $tags) \
    $output
