# syntax=docker/dockerfile:1
# TwinCAT 3.1 XAR (user mode) image. The package set comes from flavors/*.conf via scripts/build.sh.
# Beckhoff credentials are only available through the BuildKit secret "apt" (a netrc file),
# so they never end up in a layer. scripts/verify-no-secrets.sh checks this before every push.
FROM debian:trixie-slim

ARG TC_PACKAGES
ARG FLAVOR
ARG DEBIAN_FRONTEND=noninteractive

RUN --mount=type=secret,id=apt,required=true \
    apt-get update \
    && apt-get install --yes --no-install-recommends curl ca-certificates \
    && curl -fsS --netrc-file /run/secrets/apt -o /usr/share/keyrings/bhf.asc https://deb.beckhoff.com/repo.pub \
    && rm -rf /var/lib/apt/lists/*

# All packages come from deb*.beckhoff.com from here on
RUN rm /etc/apt/sources.list.d/debian.sources
COPY apt-config/bhf.list apt-config/debian.sources.list /etc/apt/sources.list.d/

RUN --mount=type=secret,id=apt,required=true \
    apt-get -o Dir::Etc::netrc=/run/secrets/apt update \
    && apt-get -o Dir::Etc::netrc=/run/secrets/apt install --yes ${TC_PACKAGES} \
    && rm -rf /var/lib/apt/lists/*

# Start the TwinCAT system service in RUN mode instead of CONFIG
COPY TwinCAT/SysStartupState.reg /etc/TwinCAT/3.1/Target/RegFiles/
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

ENV TC_FLAVOR=${FLAVOR}
EXPOSE 8016/tcp 48898/tcp 48899/udp
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
