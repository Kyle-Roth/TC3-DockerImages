# shellcheck shell=sh
# Shared helpers, sourced by the other scripts.

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PROFILE_DIR=$REPO_ROOT/profiles

# Grab file names defined in profiles/*.conf
profile_names()
{
    for file in "$PROFILE_DIR"/*.conf; do
        file=${file##*/}
        echo ${file%.conf}
    done
}

# Load PROFILE, PACKAGES, PLATFORMS from profiles/<name>.conf
# PACKAGES may hold shell patterns ("*", "tf6*")
load_profile()
{
    # profile must exist
    PROFILE=$1
    if [ ! -f "$PROFILE_DIR/$PROFILE.conf" ]; then
        echo "error: unknown profile '$PROFILE'" >&2;
        exit 1;
    fi

    PACKAGES="" PLATFORMS=""
    . "$PROFILE_DIR/$PROFILE.conf"
    # use default PLATFORMS if not defined
    PLATFORMS=${PLATFORMS:-linux/amd64,linux/arm64}

    # PACKAGES can't be empty
    if [ ! "$PACKAGES" ]; then
        echo "error: profile '$PROFILE' has no PACKAGES"
        exit 1
    fi
}

# Source BHF_USER and BHF_PASSWORD from .env
dotenv_get() {
    if [ ! -f "$REPO_ROOT/.env" ]; then
        echo "error: $REPO_ROOT/.env does not exist"
        exit 1
    fi

    . $REPO_ROOT/.env
}

# Write BHF_USER/BHF_PASSWORD (environment, else .env) to a temporary netrc file
# at $AUTH_FILE. It is removed when the calling script exits.
require_auth() {
    # load .env if user and pass not already defined
    if [ ! "${BHF_USER:-}" ] || [ ! "${BHF_PASSWORD:-}" ]; then
     dotenv_get
    fi

    # user and password can't be empty
    if [ ! "${BHF_USER:-}" ] || [ ! "${BHF_PASSWORD:-}" ]; then
       echo "error: BHF_USER and BHF_PASSWORD must be set"
       exit 1
    fi
    # user and password can't contain white spaces
    if [ "$BHF_USER$BHF_PASSWORD" = *[[:space:]]* ]; then
        echo "error: BHF_USER and BHF_PASSWORD can not contain whitespace"
        exit 1
    fi

    # generate temporary file and set it to delete on shell exit
    AUTH_FILE=$(umask 077 && mktemp)
    trap 'rm -f "$AUTH_FILE"' EXIT
    trap 'exit 130' INT TERM

    # write apt repository with crediential to temporary file
    for _h in deb.beckhoff.com deb-mirror.beckhoff.com; do
        echo "machine $_h login $BHF_USER password $BHF_PASSWORD"
    done > "$AUTH_FILE"

    # cleanup credentials
    unset BHF_USER BHF_PASSWORD
}
