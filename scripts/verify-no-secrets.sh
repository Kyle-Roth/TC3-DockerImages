#!/bin/sh
# Fail if the Beckhoff login or password appears anywhere in a local image:
# layer contents, file names (auth.conf, *.netrc), image config or build history.
#   scripts/verify-no-secrets.sh <image>
set -eu
. "$(dirname -- "$0")/lib.sh"

image=${1:?usage: $0 <image>}
require_auth
work=$(mktemp -d)
trap 'rm -rf "$work" "$AUTH_FILE"' EXIT

awk '{ print $4; print $6 }' "$AUTH_FILE" | sort -u > "$work/patterns"
fail=0

if { docker image inspect "$image"; docker history --no-trunc "$image"; } | grep -qaFf "$work/patterns"; then
    echo "FAIL: credentials in image config or history" >&2; fail=1
fi

# `docker save` layers are plain tar, or gzip with the containerd image store
cat_layer() { if [ "$(od -An -tx1 -N2 "$1" | tr -d ' ')" = 1f8b ]; then gzip -cd "$1"; else cat "$1"; fi; }

docker save "$image" | tar -x -C "$work"
layers=0
for blob in $(find "$work" -type f \( -path '*/blobs/*' -o -name layer.tar \)); do
    cat_layer "$blob" | tar -t >/dev/null 2>&1 || continue   # skip json configs/manifests
    layers=$((layers + 1))
    if cat_layer "$blob" | tar -t | grep -E '(^|/)(auth\.conf|[^/]*\.netrc|bhf\.conf)$'; then
        echo "FAIL: credential file(s) above in layer ${blob##*/}" >&2; fail=1
    fi
    if cat_layer "$blob" | grep -qaFf "$work/patterns"; then
        echo "FAIL: credentials in layer ${blob##*/}" >&2; fail=1
    fi
done

[ "$layers" -gt 0 ] || die "no layers found in $image"
[ "$fail" -eq 0 ] || die "$image failed the secret scan"
echo ">>> $image: no credentials found ($layers layers)"
