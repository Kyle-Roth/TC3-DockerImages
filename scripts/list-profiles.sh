#!/bin/sh
# List profiles and their packages, or with --json the names as a CI matrix array.
set -eu
. "$(dirname -- "$0")/lib.sh"

if [ "${1:-}" = --json ]; then
    profile_names | awk '{ printf "%s\"%s\"", (NR > 1 ? "," : "["), $0 } END { print "]" }'
else
    for n in $(profile_names); do
        load_profile "$n"
        printf '%-13s %-24s %s\n' "$PROFILE" "$PLATFORMS" "$PACKAGES"
    done
fi
