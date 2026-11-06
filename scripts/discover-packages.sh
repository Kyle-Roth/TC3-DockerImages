#!/bin/sh
# List TwinCAT packages in the Beckhoff RT Linux apt repository, for flavors/*.conf.
#
# Usage: scripts/discover-packages.sh [regex]   (default: TwinCAT packages; '.' = whole repo)
#        PLATFORM=linux/arm64 scripts/discover-packages.sh
#
# Runs in a throwaway container; credentials are bind-mounted read-only, never baked in.
set -eu
. "$(dirname -- "$0")/lib.sh"
require_auth_conf
trap cleanup_auth_conf EXIT
trap 'exit 130' INT TERM

docker run --rm ${PLATFORM:+--platform "$PLATFORM"} \
    -v "$APT_AUTH_CONF:/run/secrets/apt:ro" \
    -v "$REPO_ROOT/docker/apt-config/bhf.list:/etc/apt/bhf.list:ro" \
    -e PATTERN="${1:-^(tc|tf|te)[0-9]|^adstool\$}" \
    -e DEBIAN_FRONTEND=noninteractive \
    debian:trixie-slim sh -euc '
        # quiet setup; show the log only on failure
        run() { "$@" >>/tmp/setup.log 2>&1 || { cat /tmp/setup.log >&2; exit 1; }; }
        run apt-get update
        run apt-get install --yes --no-install-recommends curl ca-certificates
        run curl -fsS --netrc-file /run/secrets/apt -o /usr/share/keyrings/bhf.asc https://deb.beckhoff.com/repo.pub
        # index the Beckhoff repo only (no Debian mirror packages)
        rm -rf /etc/apt/sources.list.d/* /etc/apt/sources.list /var/lib/apt/lists/*
        cp /etc/apt/bhf.list /etc/apt/sources.list.d/bhf.list
        run apt-get -o Dir::Etc::netrc=/run/secrets/apt update
        # "name - description" for every package in the Beckhoff index
        awk -v pat="$PATTERN" "
            /^Package: /     { pkg = \$2 }
            /^Description: / { if (pkg ~ pat && pkg !~ /-dbgsym\$/) { sub(/^Description: /, \"\"); print pkg \" - \" \$0 } }
        " <<EOF | sort -u
$(apt-get indextargets --format "\$(FILENAME)" "Created-By: Packages" | xargs /usr/lib/apt/apt-helper cat-file)
EOF
    '
