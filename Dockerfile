# syntax=docker/dockerfile:1.7

FROM node:22-bookworm AS builder

ARG WRAPPER_SHA
ARG OFFICIAL_VERSION
ARG OFFICIAL_PATH
ARG OFFICIAL_SHA256

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        dpkg-dev \
        g++ \
        gcc \
        git \
        gnupg \
        gpgv \
        make \
        pkg-config \
        python3 \
        tar \
        unzip \
        util-linux \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN test -n "${WRAPPER_SHA}" \
    && test -n "${OFFICIAL_VERSION}" \
    && test -n "${OFFICIAL_PATH}" \
    && test -n "${OFFICIAL_SHA256}"

WORKDIR /src

RUN git init . \
    && git remote add origin https://github.com/ilysenko/codex-desktop-linux.git \
    && git fetch --depth=1 origin "${WRAPPER_SHA}" \
    && git checkout --detach FETCH_HEAD

RUN mkdir -p linux-features \
    && printf '%s\n' \
        '{' \
        '  "enabled": [' \
        '    "remote-mobile-control"' \
        '  ]' \
        '}' \
        > linux-features/features.json

RUN curl -fsSL \
        "https://persistent.oaistatic.com/codex-app-prod/linux/deb/${OFFICIAL_PATH}" \
        -o /tmp/chatgpt.deb \
    && echo "${OFFICIAL_SHA256}  /tmp/chatgpt.deb" | sha256sum -c -

RUN UPSTREAM_DEB=/tmp/chatgpt.deb make build-app \
    && PACKAGE_WITH_UPDATER=0 \
       PACKAGE_VERSION="${OFFICIAL_VERSION}" \
       make deb


FROM lscr.io/linuxserver/webtop:ubuntu-xfce

ENV CODEX_LINUX_DISABLE_USAGE_REPORTING=1
ENV CODEX_OZONE_PLATFORM=x11

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        iputils-ping \
        jq \
        openssh-client \
        procps \
        rsync \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/dist/*.deb /tmp/codex-desktop.deb

RUN apt-get update \
    && apt-get install -y /tmp/codex-desktop.deb \
    && rm -f /tmp/codex-desktop.deb \
    && rm -rf /var/lib/apt/lists/*

COPY root/ /

RUN chmod 0755 \
        /custom-cont-init.d/10-chatgpt-unraid.sh \
        /usr/local/bin/start-chatgpt-community
