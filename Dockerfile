FROM debian:bookworm-slim

ARG HOST_UID
ARG HOST_GID
ARG CODEX_VERSION
ARG CODEX_TARGET

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        bubblewrap \
        curl \
        git \
        openssh-client \
        ripgrep \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    if [ "${CODEX_VERSION}" = "latest" ]; then \
        url="https://github.com/openai/codex/releases/latest/download/codex-${CODEX_TARGET}.tar.gz"; \
    else \
        url="https://github.com/openai/codex/releases/download/${CODEX_VERSION}/codex-${CODEX_TARGET}.tar.gz"; \
    fi; \
    curl -fsSL "${url}" -o /tmp/codex.tar.gz; \
    tar -xzf /tmp/codex.tar.gz -C /usr/local/bin/; \
    mv "/usr/local/bin/codex-${CODEX_TARGET}" /usr/local/bin/codex; \
    chmod 755 /usr/local/bin/codex; \
    rm /tmp/codex.tar.gz

RUN set -eux; \
    mkdir -p /home/codex/.codex /home/codex/.cache \
    && if ! getent group "${HOST_GID}" >/dev/null; then groupadd --gid "${HOST_GID}" codex; fi \
    && if ! id -u "${HOST_UID}" >/dev/null 2>&1; then useradd --uid "${HOST_UID}" --gid "${HOST_GID}" --home-dir /home/codex --shell /bin/bash codex; fi \
    && chown -R "${HOST_UID}:${HOST_GID}" /home/codex/

ENV HOME=/home/codex/

WORKDIR /workspace

USER codex
