#!/bin/sh
# Verify that a locally available image contains no Beckhoff credentials.
#
# Usage: scripts/verify-no-secrets.sh <image>
#
# Checks:
#   1. no credential files (bhf.conf, auth.conf, *.netrc) in any layer
#   2. no login/password value from $APT_AUTH_CONF in any layer's content
#   3. no login/password value in image config (env, labels, cmd) or build history
# The secret values themselves are never printed.
set -eu
. "$(dirname -- "$0")/lib.sh"

image=${1:?usage: $0 <image>}
require_auth_conf

work=$(mktemp -d "${TMPDIR:-/tmp}/verify-secrets.XXXXXX")
trap 'rm -rf "$work"; cleanup_auth_conf' EXIT
trap 'exit 130' INT TERM

netrc_secrets "$APT_AUTH_CONF" > "$work/secrets"
count=$(awk 'length($0) >= 4' "$work/secrets" | wc -l)
[ "$count" -gt 0 ] || die "no login/password entries found in $APT_AUTH_CONF"
awk 'length($0) >= 4' "$work/secrets" > "$work/patterns"

fail=0
echo ">>> verifying $image against $count credential value(s)"

# 3. image metadata + history
if { docker image inspect "$image"; docker history --no-trunc --format '{{.CreatedBy}}' "$image"; } \
        | grep -qaFf "$work/patterns"; then
    echo "FAIL: credential value found in image config or history" >&2
    fail=1
fi

# 1 + 2. layer contents
docker save "$image" -o "$work/image.tar"
mkdir "$work/img"
tar -xf "$work/image.tar" -C "$work/img"

decompress() {
    # layers are uncompressed in `docker save` output, but handle gzip/zstd just in case
    magic=$(od -An -tx1 -N4 "$1" | tr -d ' \n')
    case $magic in
        1f8b*) gzip -cd "$1" ;;
        28b52ffd) zstd -cdq "$1" ;;
        *) cat "$1" ;;
    esac
}

layers=0
for blob in $(find "$work/img" -type f \( -path '*/blobs/*' -o -name 'layer.tar' \)); do
    # only tar archives are layers (skip json manifests/configs)
    decompress "$blob" | tar -t >/dev/null 2>&1 || continue
    layers=$((layers + 1))
    bad_files=$(decompress "$blob" | tar -t 2>/dev/null \
        | grep -E '(^|/)(bhf\.conf|auth\.conf|[^/]*\.netrc|\.netrc)$' \
        | grep -v '^run/secrets/' || true)
    if [ -n "$bad_files" ]; then
        echo "FAIL: credential file(s) in layer ${blob##*/}:" >&2
        echo "$bad_files" | sed 's/^/        /' >&2
        fail=1
    fi
    if decompress "$blob" | grep -qaFf "$work/patterns"; then
        echo "FAIL: credential value found in content of layer ${blob##*/}" >&2
        fail=1
    fi
done

[ "$layers" -gt 0 ] || die "no layers found in saved image - cannot verify"

if [ "$fail" -ne 0 ]; then
    echo ">>> $image FAILED secret scan" >&2
    exit 1
fi
echo ">>> OK: scanned $layers layer(s), config and history - no credentials found"
