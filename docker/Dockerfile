# syntax=docker/dockerfile:1
#
# Parameterized TwinCAT 3.1 XAR (user mode) image.
# The flavor (package set) is selected via build args, see flavors/*.conf and scripts/build.sh.
#
# Beckhoff repository credentials are ONLY provided through a BuildKit secret
# (--secret id=apt,src=<netrc file>). They are never written to a layer, ARG or ENV.

ARG BASE_IMAGE=debian:trixie-slim
FROM ${BASE_IMAGE}

ARG FLAVOR=basic
ARG TC_PACKAGES="tc31-xar-um adstool"
ARG BUILD_REF=unknown
ARG BUILD_DATE=unknown
ARG IMAGE_SOURCE=""

# Install curl and ca-certificates to load the bhf.asc signing key from beckhoff.com during build
RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Authenticate against deb*.beckhoff.com with the netrc secret (apt_auth.conf(5) format)
RUN --mount=type=secret,id=apt,required=true \
    curl --fail --silent --show-error --netrc-file /run/secrets/apt \
    -o /usr/share/keyrings/bhf.asc \
    https://deb.beckhoff.com/repo.pub

# Replace default debian.org package sources.
# From here on, all packages will be loaded from deb*.beckhoff.com
RUN rm -f /etc/apt/sources.list.d/debian.sources
COPY apt-config/bhf.list apt-config/debian.sources.list /etc/apt/sources.list.d/

# Install the TwinCAT packages for this flavor
RUN --mount=type=secret,id=apt,required=true \
    apt-get -o "Dir::Etc::netrc=/run/secrets/apt" update \
    && apt-get -o "Dir::Etc::netrc=/run/secrets/apt" install --yes ${TC_PACKAGES} \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*.bin

# Scrub: make sure no apt credential material can remain in the image
RUN rm -rf /etc/apt/auth.conf /etc/apt/auth.conf.d/* /root/.netrc \
    && find / -xdev \( -name 'bhf.conf' -o -name '*.netrc' \) -exec rm -f {} + 2>/dev/null || true

# Start the TwinCAT system service in RUN mode (instead of CONFIG)
ARG TC3_DIR=/etc/TwinCAT/3.1
COPY TwinCAT/SysStartupState.reg ${TC3_DIR}/Target/RegFiles/

ENV TC_FLAVOR=${FLAVOR}

LABEL org.opencontainers.image.title="tc31-xar-${FLAVOR}" \
      org.opencontainers.image.description="TwinCAT 3.1 XAR user-mode runtime (${FLAVOR})" \
      org.opencontainers.image.revision="${BUILD_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="${IMAGE_SOURCE}" \
      com.beckhoff.twincat.flavor="${FLAVOR}" \
      com.beckhoff.twincat.packages="${TC_PACKAGES}"

EXPOSE 8016/tcp
EXPOSE 48898/tcp
EXPOSE 48899/udp

WORKDIR /app
COPY --chmod=755 docker-entrypoint.sh entrypoint.sh /app/

# Runtime apt credentials (never baked in): pass BHF_USER + BHF_PASSWORD, or
# BHF_AUTH_FILE pointing to a mounted netrc file. See docker-entrypoint.sh.
ENTRYPOINT [ "/app/docker-entrypoint.sh" ]
CMD [ "/bin/sh", "/app/entrypoint.sh" ]
