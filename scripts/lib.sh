# shellcheck shell=sh
# Shared helpers for the build scripts. Source this file; do not execute it.

REPO_ROOT=${REPO_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}
FLAVOR_DIR=${FLAVOR_DIR:-$REPO_ROOT/flavors}
ENV_FILE=${ENV_FILE:-$REPO_ROOT/.env}
DEFAULT_AUTH_CONF=$REPO_ROOT/docker/apt-config/bhf.conf
BHF_HOSTS=${BHF_HOSTS:-"deb.beckhoff.com deb-mirror.beckhoff.com"}

die() { echo "error: $*" >&2; exit 1; }

# Print all flavor names (basename of flavors/*.conf), sorted.
flavor_names() {
    for f in "$FLAVOR_DIR"/*.conf; do
        [ -e "$f" ] || continue
        n=${f##*/}
        echo "${n%.conf}"
    done | sort
}

# Load a flavor into the variables FLAVOR, DESCRIPTION, PACKAGES, PLATFORMS.
# A flavor may set INCLUDE_FLAVORS="a b" (or "*" for every other flavor that
# does not itself use INCLUDE_FLAVORS) to merge their PACKAGES into its own.
load_flavor() {
    FLAVOR=$1
    _file="$FLAVOR_DIR/$FLAVOR.conf"
    [ -f "$_file" ] || die "unknown flavor '$FLAVOR' (no $_file)"

    DESCRIPTION="" PACKAGES="" PLATFORMS="" INCLUDE_FLAVORS=""
    # shellcheck disable=SC1090
    . "$_file"
    _own_packages=$PACKAGES _own_desc=$DESCRIPTION _own_platforms=$PLATFORMS
    _includes=$INCLUDE_FLAVORS

    if [ "$_includes" = "*" ]; then
        _includes=""
        for _n in $(flavor_names); do
            [ "$_n" = "$FLAVOR" ] && continue
            INCLUDE_FLAVORS=""
            # shellcheck disable=SC1090
            . "$FLAVOR_DIR/$_n.conf"
            [ -z "$INCLUDE_FLAVORS" ] && _includes="$_includes $_n"
        done
    fi

    _all=$_own_packages
    for _n in $_includes; do
        [ "$_n" = "$FLAVOR" ] && continue
        [ -f "$FLAVOR_DIR/$_n.conf" ] || die "flavor '$FLAVOR' includes unknown flavor '$_n'"
        PACKAGES="" INCLUDE_FLAVORS=""
        # shellcheck disable=SC1090
        . "$FLAVOR_DIR/$_n.conf"
        [ -n "$INCLUDE_FLAVORS" ] && die "nested INCLUDE_FLAVORS not supported ('$_n')"
        _all="$_all $PACKAGES"
    done

    # De-duplicate while preserving order
    PACKAGES=$(printf '%s\n' $_all | awk 'NF && !seen[$0]++' | tr '\n' ' ' | sed 's/ $//')
    DESCRIPTION=$_own_desc
    PLATFORMS=${_own_platforms:-linux/amd64,linux/arm64}
    INCLUDE_FLAVORS=$_includes
    [ -n "$PACKAGES" ] || die "flavor '$FLAVOR' has no PACKAGES"
}

# Extract login and password values from a netrc / apt auth file, one per line.
netrc_secrets() {
    awk '{ for (i = 1; i < NF; i++) if ($i == "login" || $i == "password") print $(i + 1) }' "$1" | sort -u
}

# Read KEY from a dotenv file without sourcing it (values may contain $, !, spaces).
# Supports KEY=value, KEY="value", KEY='value', optional leading "export ".
dotenv_get() {
    [ -f "$2" ] || return 0
    awk -v key="$1" '
        { sub(/\r$/, "") }
        /^[[:space:]]*(#|$)/ { next }
        {
            line = $0
            sub(/^[[:space:]]*(export[[:space:]]+)?/, "", line)
            eq = index(line, "=")
            if (eq == 0) next
            k = substr(line, 1, eq - 1); gsub(/[[:space:]]+$/, "", k)
            if (k != key) next
            v = substr(line, eq + 1)
            if (v ~ /^".*"$/ || v ~ /^\047.*\047$/) v = substr(v, 2, length(v) - 2)
            val = v
        }
        END { printf "%s", val }
    ' "$2"
}

# Resolve the Beckhoff credentials into a netrc file and set APT_AUTH_CONF.
# Precedence:
#   1. BHF_USER + BHF_PASSWORD from the environment
#   2. BHF_USER + BHF_PASSWORD from $ENV_FILE (repo-root .env)
#   3. APT_AUTH_CONF (explicit netrc file), else docker/apt-config/bhf.conf
# Sets AUTH_SOURCE to where they came from.
# For 1/2 a temporary netrc (mode 600) is created; callers must call cleanup_auth_conf.
_GENERATED_AUTH_CONF=""
require_auth_conf() {
    _user=${BHF_USER:-} _pass=${BHF_PASSWORD:-} _src="environment"
    if [ -z "$_user" ] || [ -z "$_pass" ]; then
        _user=$(dotenv_get BHF_USER "$ENV_FILE")
        _pass=$(dotenv_get BHF_PASSWORD "$ENV_FILE")
        _src=$ENV_FILE
    fi

    if [ -n "$_user" ] && [ -n "$_pass" ]; then
        case "$_user$_pass" in
            *[[:space:]]*) die "BHF_USER/BHF_PASSWORD from $_src contain whitespace, which netrc/apt auth.conf cannot represent" ;;
        esac
        _GENERATED_AUTH_CONF=$(umask 077 && mktemp "${TMPDIR:-/tmp}/bhf-netrc.XXXXXX")
        for _h in $BHF_HOSTS; do
            printf 'machine %s login %s password %s\n' "$_h" "$_user" "$_pass"
        done > "$_GENERATED_AUTH_CONF"
        APT_AUTH_CONF=$_GENERATED_AUTH_CONF
        AUTH_SOURCE=$_src
    else
        APT_AUTH_CONF=${APT_AUTH_CONF:-$DEFAULT_AUTH_CONF}
        [ -f "$APT_AUTH_CONF" ] || die "no Beckhoff credentials: set BHF_USER/BHF_PASSWORD in .env
       (see .env.example) or point APT_AUTH_CONF to a netrc file"
        AUTH_SOURCE=$APT_AUTH_CONF
    fi
    unset _user _pass
}

cleanup_auth_conf() {
    [ -n "$_GENERATED_AUTH_CONF" ] && rm -f "$_GENERATED_AUTH_CONF"
    _GENERATED_AUTH_CONF=""
}
