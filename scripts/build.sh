#!/usr/bin/sh
# Build one profile.
#   scripts/build.sh <profile>               host platform, loaded into local docker
#   scripts/build.sh <profile> --push        all PLATFORMS, pushed to $REGISTRY/$IMAGE_OWNER
#   scripts/build.sh <profile> --print-tags  print the image tags and exit
# Env: REGISTRY, IMAGE_OWNER, IMAGE_NAME (default tc31-xar), BUILD_REF (default git HEAD),
#      IMAGE_SOURCE: repo URL for the org.opencontainers.image.source label (links a GHCR package),
#      CHANNEL: release tags <profile>, <profile>-YYYYMMDD and, for full, latest;
#               dev tags <profile>-dev and <profile>-<sha>
set -eu
. "$(dirname -- "$0")/lib.sh"

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "usage: $0 <profile> [--push | --print-tags]"
    exit 1
fi

load_profile "$1"
mode=${2:-}

ref=${BUILD_REF:-$(git -C "$REPO_ROOT" rev-parse HEAD)}
image=$(echo "${REGISTRY:+$REGISTRY/}${IMAGE_OWNER:+$IMAGE_OWNER/}${IMAGE_NAME:-tc31-xar}" | tr '[:upper:]' '[:lower:]')
case ${CHANNEL:-release} in
    release)
        tags="$image:$PROFILE $image:$PROFILE-$(date -u +%Y%m%d)"
        [ "$PROFILE" = full ] && tags="$tags $image:latest" ;;
    dev)
        tags="$image:$PROFILE-dev $image:$PROFILE-$(printf '%.7s' "$ref")" ;;
    *)
        { echo "error: unknown CHANNEL '$CHANNEL' (release|dev)" >&2; exit 1; } ;;
esac

case $mode in
    --print-tags)
        printf '%s\n' $tags;
        exit 0 ;;
    --push)
        platforms=$PLATFORMS output=--push ;;
    "")
        platforms=linux/$(docker version --format '{{.Server.Arch}}') output=--load ;;
    *)
        { echo "error: unknown option: $mode" >&2; exit 1; } ;;
esac

require_auth
echo ">>> $PROFILE [$platforms]: $PACKAGES"
# shellcheck disable=SC2046
docker buildx build "$REPO_ROOT/docker" \
    --secret "id=apt,src=$AUTH_FILE" \
    --platform "$platforms" \
    --build-arg "PROFILE=$PROFILE" \
    --build-arg "TC_PACKAGES=$PACKAGES" \
    --provenance=false \
    ${IMAGE_SOURCE:+--label "org.opencontainers.image.source=$IMAGE_SOURCE"} \
    $(printf -- '--tag %s ' $tags) \
    $output
