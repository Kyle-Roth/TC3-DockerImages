#!/bin/sh
# List packages in the Beckhoff apt repository (default: TwinCAT packages).
#   scripts/discover-packages.sh [regex]
#   PLATFORM=linux/arm64 scripts/discover-packages.sh
set -eu
. "$(dirname -- "$0")/lib.sh"
require_auth

docker run --rm ${PLATFORM:+--platform "$PLATFORM"} \
    -v "$AUTH_FILE:/run/secrets/apt:ro" \
    -v "$REPO_ROOT/docker/apt-config/bhf.list:/tmp/bhf.list:ro" \
    -e PATTERN="${1:-^(tc|tf|te)[0-9]|^adstool\$}" \
    -e DEBIAN_FRONTEND=noninteractive \
    debian:trixie-slim sh -euc '
        run() { "$@" >>/tmp/log 2>&1 || { cat /tmp/log >&2; exit 1; }; }
        run apt-get update
        run apt-get install --yes --no-install-recommends curl ca-certificates
        run curl -fsS --netrc-file /run/secrets/apt -o /usr/share/keyrings/bhf.asc https://deb.beckhoff.com/repo.pub
        rm -rf /etc/apt/sources.list.d/* /var/lib/apt/lists/*
        cp /tmp/bhf.list /etc/apt/sources.list.d/
        run apt-get -o Dir::Etc::netrc=/run/secrets/apt update
        apt-get indextargets --format "\$(FILENAME)" "Created-By: Packages" \
            | xargs /usr/lib/apt/apt-helper cat-file \
            | awk -v pat="$PATTERN" "/^Package: /{p=\$2} /^Description: /{ if (p ~ pat && p !~ /-dbgsym\$/) print p \" - \" substr(\$0, 14) }" \
            | sort -u
    '
