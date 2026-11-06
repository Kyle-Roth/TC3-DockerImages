#!/bin/sh
# List available flavors.
#   list-flavors.sh          -> human readable table
#   list-flavors.sh --json   -> JSON array for a CI matrix, e.g. ["all","basic"]
#   list-flavors.sh --json basic,motion  -> only the given (validated) flavors
set -eu
. "$(dirname -- "$0")/lib.sh"

mode=table
if [ "${1:-}" = "--json" ]; then mode=json; shift; fi
filter=${1:-}

if [ -n "$filter" ]; then
    names=$(echo "$filter" | tr ', ' '\n\n' | awk 'NF')
    for n in $names; do [ -f "$FLAVOR_DIR/$n.conf" ] || die "unknown flavor '$n'"; done
else
    names=$(flavor_names)
fi

if [ "$mode" = json ]; then
    printf '%s\n' $names | awk 'BEGIN { printf "[" } { printf "%s\"%s\"", (NR > 1 ? "," : ""), $0 } END { print "]" }'
else
    for n in $names; do
        load_flavor "$n"
        printf '%-10s %-28s %s\n' "$FLAVOR" "$PLATFORMS" "$DESCRIPTION"
        printf '%-10s packages: %s\n' "" "$PACKAGES"
    done
fi
