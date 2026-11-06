# shellcheck shell=sh
# Shared helpers, sourced by the other scripts.

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
FLAVOR_DIR=$REPO_ROOT/flavors

die() { echo "error: $*" >&2; exit 1; }

flavor_names() {
    for f in "$FLAVOR_DIR"/*.conf; do n=${f##*/}; echo "${n%.conf}"; done
}

# Load flavors/<name>.conf into FLAVOR, PACKAGES, PLATFORMS.
# PACKAGES="*" means: the packages of every other flavor.
load_flavor() {
    FLAVOR=$1
    [ -f "$FLAVOR_DIR/$FLAVOR.conf" ] || die "unknown flavor '$FLAVOR'"
    PACKAGES="" PLATFORMS=""
    . "$FLAVOR_DIR/$FLAVOR.conf"
    _platforms=${PLATFORMS:-linux/amd64,linux/arm64}
    if [ "$PACKAGES" = "*" ]; then
        _all=""
        for _n in $(flavor_names); do
            [ "$_n" = "$FLAVOR" ] && continue
            PACKAGES=""
            . "$FLAVOR_DIR/$_n.conf"
            [ "$PACKAGES" = "*" ] || _all="$_all $PACKAGES"
        done
        PACKAGES=$(printf '%s\n' $_all | awk '!seen[$0]++' | xargs)
    fi
    PLATFORMS=$_platforms
    [ -n "$PACKAGES" ] || die "flavor '$FLAVOR' has no PACKAGES"
}

# Read KEY from .env without sourcing it, so values may contain $, ! etc.
dotenv_get() {
    [ -f "$REPO_ROOT/.env" ] || return 0
    sed -n "s/^[[:space:]]*\(export[[:space:]]*\)\{0,1\}$1=//p" "$REPO_ROOT/.env" \
        | tail -n1 | tr -d '\r' | sed "s/^\"\(.*\)\"$/\1/; s/^'\(.*\)'$/\1/"
}

# Write BHF_USER/BHF_PASSWORD (environment, else .env) to a temporary netrc file
# at $AUTH_FILE. It is removed when the calling script exits.
require_auth() {
    _user=${BHF_USER:-$(dotenv_get BHF_USER)}
    _pass=${BHF_PASSWORD:-$(dotenv_get BHF_PASSWORD)}
    [ -n "$_user" ] && [ -n "$_pass" ] || die "set BHF_USER and BHF_PASSWORD in .env (see .env.example)"
    case "$_user$_pass" in *[[:space:]]*) die "BHF_USER/BHF_PASSWORD must not contain whitespace" ;; esac
    AUTH_FILE=$(umask 077 && mktemp)
    trap 'rm -f "$AUTH_FILE"' EXIT
    trap 'exit 130' INT TERM
    for _h in deb.beckhoff.com deb-mirror.beckhoff.com; do
        echo "machine $_h login $_user password $_pass"
    done > "$AUTH_FILE"
    unset _user _pass
}
