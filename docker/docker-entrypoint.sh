#!/bin/sh
# SPDX-License-Identifier: Zero-Clause BSD
#
# Container entrypoint: optionally configures Beckhoff apt credentials at runtime,
# then executes the given command (default: the TwinCAT system service).
#
# No credentials are stored in the image. To use apt inside a running container,
# pass them in one of these ways:
#   -e BHF_USER=... -e BHF_PASSWORD=...
#   -e BHF_AUTH_FILE=/run/secrets/bhf  (+ mount a netrc / apt_auth.conf file there)
# The credentials are written to /etc/apt/auth.conf.d/bhf.conf (mode 600) inside
# the container's writable layer only.
set -e

AUTH_DEST=/etc/apt/auth.conf.d/bhf.conf
BHF_HOSTS=${BHF_HOSTS:-"deb.beckhoff.com deb-mirror.beckhoff.com"}

if [ -n "${BHF_AUTH_FILE:-}" ]; then
    if [ ! -r "$BHF_AUTH_FILE" ]; then
        echo "error: BHF_AUTH_FILE=$BHF_AUTH_FILE is not readable" >&2
        exit 1
    fi
    mkdir -p "${AUTH_DEST%/*}"
    install -m 600 "$BHF_AUTH_FILE" "$AUTH_DEST"
    echo "apt: Beckhoff credentials loaded from $BHF_AUTH_FILE"
elif [ -n "${BHF_USER:-}" ] && [ -n "${BHF_PASSWORD:-}" ]; then
    mkdir -p "${AUTH_DEST%/*}"
    ( umask 077
      for host in $BHF_HOSTS; do
          printf 'machine %s login %s password %s\n' "$host" "$BHF_USER" "$BHF_PASSWORD"
      done > "$AUTH_DEST" )
    echo "apt: Beckhoff credentials configured from BHF_USER/BHF_PASSWORD"
elif [ -n "${BHF_USER:-}${BHF_PASSWORD:-}" ]; then
    echo "warning: both BHF_USER and BHF_PASSWORD must be set; apt credentials not configured" >&2
fi

# Don't leak the password to child processes (TwinCAT service, shells, ...)
unset BHF_PASSWORD

exec "$@"
