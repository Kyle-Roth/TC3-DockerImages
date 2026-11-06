#!/bin/sh
# Build (and optionally push) one TwinCAT image flavor.
#
# Usage: scripts/build.sh <flavor> [--push] [--platform <list>] [--print-tags]
#
#   default      build for the host platform only and --load into the local docker
#   --push       build for all flavor PLATFORMS and push all tags to the registry
#   --platform   override the platform list
#   --print-tags only print the tags that would be used, then exit
#
# Environment:
#   REGISTRY       registry host, e.g. git.example.com (empty = local only)
#   IMAGE_OWNER    registry namespace / Forgejo owner, e.g. myorg
#   IMAGE_NAME     image repository name (default: tc31-xar)
#   LATEST_FLAVOR  flavor that also gets the 'latest' tag (default: all)
#   BUILD_REF      git revision label (default: git rev-parse HEAD)
#   BUILD_DATE_TAG date tag part (default: today, YYYYMMDD)
#   BHF_USER/BHF_PASSWORD  Beckhoff credentials (env, else read from .env)
#   APT_AUTH_CONF  fallback netrc file (default: docker/apt-config/bhf.conf)
#   EXTRA_BUILD_ARGS  extra arguments passed verbatim to docker buildx build
set -eu
. "$(dirname -- "$0")/lib.sh"

[ $# -ge 1 ] || die "usage: $0 <flavor> [--push] [--platform <list>] [--print-tags]"
flavor=$1; shift
push=0 platform_override="" print_tags=0
while [ $# -gt 0 ]; do
    case $1 in
        --push) push=1 ;;
        --platform) platform_override=${2:?--platform needs a value}; shift ;;
        --print-tags) print_tags=1 ;;
        *) die "unknown option: $1" ;;
    esac
    shift
done

load_flavor "$flavor"

IMAGE_NAME=${IMAGE_NAME:-tc31-xar}
LATEST_FLAVOR=${LATEST_FLAVOR:-all}
BUILD_REF=${BUILD_REF:-$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo unknown)}
BUILD_DATE_TAG=${BUILD_DATE_TAG:-$(date -u +%Y%m%d)}
short_ref=$(printf '%.7s' "$BUILD_REF")

# Registry paths must be lowercase
image=$(printf '%s' "${REGISTRY:+$REGISTRY/}${IMAGE_OWNER:+$IMAGE_OWNER/}$IMAGE_NAME" | tr '[:upper:]' '[:lower:]')

tags="$image:$FLAVOR $image:$FLAVOR-$BUILD_DATE_TAG"
[ "$short_ref" != unknown ] && tags="$tags $image:$FLAVOR-$short_ref"
[ "$FLAVOR" = "$LATEST_FLAVOR" ] && tags="$tags $image:latest"

if [ "$print_tags" = 1 ]; then printf '%s\n' $tags; exit 0; fi

if [ -n "$platform_override" ]; then
    platforms=$platform_override
elif [ "$push" = 1 ]; then
    platforms=$PLATFORMS
else
    # --load only supports a single platform on the classic docker image store
    platforms="linux/$(docker version --format '{{.Server.Arch}}')"
fi

require_auth_conf
trap cleanup_auth_conf EXIT
trap 'exit 130' INT TERM

set -- docker buildx build \
    --file "$REPO_ROOT/docker/Dockerfile" \
    --secret "id=apt,src=$APT_AUTH_CONF" \
    --platform "$platforms" \
    --build-arg "FLAVOR=$FLAVOR" \
    --build-arg "TC_PACKAGES=$PACKAGES" \
    --build-arg "BUILD_REF=$BUILD_REF" \
    --build-arg "BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --build-arg "IMAGE_SOURCE=${IMAGE_SOURCE:-}" \
    --provenance=false
for t in $tags; do set -- "$@" --tag "$t"; done
if [ "$push" = 1 ]; then set -- "$@" --push; else set -- "$@" --load; fi
# shellcheck disable=SC2086
set -- "$@" ${EXTRA_BUILD_ARGS:-} "$REPO_ROOT/docker"

echo ">>> flavor:    $FLAVOR"
echo ">>> creds:     $AUTH_SOURCE"
echo ">>> packages:  $PACKAGES"
echo ">>> platforms: $platforms"
echo ">>> tags:      $tags"
"$@"
