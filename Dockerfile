# syntax=docker/dockerfile:1
# AdGuard VPN CLI (official, closed-source binary) supervised for a shared
# Docker network namespace. See README.md.
ARG DEBIAN_TAG=13.7-slim

# The download and signature check run natively on the build host; the binary
# itself is x86_64 whatever the host is.
FROM --platform=$BUILDPLATFORM debian:${DEBIAN_TAG} AS fetch
# renovate: datasource=github-releases depName=AdguardTeam/AdGuardVPNCLI
ARG CLI_VERSION=1.8.2
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY adguard-release.asc .
# The keyring holds AdGuard's key only, so a good signature is one from AdGuard.
RUN curl -fsSL "https://github.com/AdguardTeam/AdGuardVPNCLI/releases/download/v${CLI_VERSION}/adguardvpn-cli-${CLI_VERSION}-linux-x86_64.tar.gz" \
      | tar xz --strip-components=1 \
 && export GNUPGHOME="$(mktemp -d)" \
 && gpg --import adguard-release.asc \
 && gpg --verify adguardvpn-cli.sig adguardvpn-cli

FROM debian:${DEBIAN_TAG}
LABEL org.opencontainers.image.source="https://github.com/ilnazziiazi/adguard-cli-docker"
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl iptables iproute2 \
 && rm -rf /var/lib/apt/lists/*
COPY --from=fetch /src/adguardvpn-cli /usr/local/bin/
COPY entrypoint.sh probe.sh /usr/local/bin/
HEALTHCHECK --interval=1m --timeout=15s --start-period=5m --retries=5 CMD ["probe.sh"]
ENTRYPOINT ["entrypoint.sh"]
