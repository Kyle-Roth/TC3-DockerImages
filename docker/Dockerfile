# syntax=docker/dockerfile:1
# TwinCAT 3.1 XAR (user mode) image. The package set comes from profiles/*.conf via scripts/build.sh.
# Beckhoff credentials are only available through the BuildKit secret "apt" (a netrc file),
# so they never end up in a layer. scripts/verify-no-secrets.sh checks this before every push.
FROM debian:trixie-slim

ARG TC_PACKAGES
ARG PROFILE
ARG DEBIAN_FRONTEND=noninteractive

RUN --mount=type=secret,id=apt,required=true \
    apt-get update \
    && apt-get install --yes --no-install-recommends curl ca-certificates \
    && curl -fsS --netrc-file /run/secrets/apt -o /usr/share/keyrings/bhf.asc https://deb.beckhoff.com/repo.pub \
    && rm -rf /var/lib/apt/lists/*

# All packages come from deb*.beckhoff.com from here on
RUN rm /etc/apt/sources.list.d/debian.sources
COPY apt-config/bhf.list apt-config/debian.sources.list /etc/apt/sources.list.d/

# No systemd in the container: let package scripts that call systemctl succeed as a no-op.
# The divert keeps this stub in place even if a package pulls in the real systemd.
RUN dpkg-divert --local --rename --add /usr/bin/systemctl && ln -s /bin/true /usr/bin/systemctl

# TC_PACKAGES entries are shell patterns ("*", "tf6*") matched against the packages in
# deb.beckhoff.com; an entry that matches nothing is passed to apt as-is.
RUN --mount=type=secret,id=apt,required=true \
    set -f \
    && apt-get -o Dir::Etc::netrc=/run/secrets/apt update \
    && avail=$(apt-get indextargets --format '$(FILENAME)' 'Created-By: Packages' 'Site: https://deb.beckhoff.com/debian' \
        | xargs /usr/lib/apt/apt-helper cat-file | sed -n 's/^Package: //p' | grep -v -- '-dbgsym$' | sort -u) \
    && pkgs=$(for p in ${TC_PACKAGES}; do \
        m=$(for a in $avail; do case $a in $p) echo "$a" ;; esac; done); echo "${m:-$p}"; done) \
    && echo "Installing:" ${pkgs} \
    && apt-get -o Dir::Etc::netrc=/run/secrets/apt install --yes ${pkgs} \
    && rm -rf /var/lib/apt/lists/*

# Start the TwinCAT system service in RUN mode instead of CONFIG
COPY TwinCAT/SysStartupState.reg /etc/TwinCAT/3.1/Target/RegFiles/
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

ENV TC_profile=${PROFILE}
EXPOSE 8016/tcp 48898/tcp 48899/udp
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
