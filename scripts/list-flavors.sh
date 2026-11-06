#!/bin/sh
# List flavors and their packages, or with --json the names as a CI matrix array.
set -eu
. "$(dirname -- "$0")/lib.sh"

if [ "${1:-}" = --json ]; then
    flavor_names | awk '{ printf "%s\"%s\"", (NR > 1 ? "," : "["), $0 } END { print "]" }'
else
    for n in $(flavor_names); do
        load_flavor "$n"
        printf '%-8s %-24s %s\n' "$FLAVOR" "$PLATFORMS" "$PACKAGES"
    done
fi
