#
# codex-container-sandbox Containerfile
#
# Goal: ship a Codex-ready container that is as self-sufficient as practical for
# common skills/tools (PDF triage, webpage→markdown, markdown querying, etc.)
# while keeping host exposure bounded via the wrapper mounts.
#

# ----------------------------
# Builder: mq (mqlang.org)
# ----------------------------
FROM docker.io/library/rust:1-bookworm AS mq_builder

# Optional: add a corporate/WBG root CA for TLS interception environments.
# Pass it as base64 bytes (either PEM or DER) via build arg EXTRA_CA_CERT_B64.
ARG EXTRA_CA_CERT_B64=""
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates git openssl \
  && rm -rf /var/lib/apt/lists/* \
  && if [ -n "${EXTRA_CA_CERT_B64}" ]; then \
      tmp=/tmp/extra-ca-cert.bin; \
      echo "${EXTRA_CA_CERT_B64}" | base64 -d > "${tmp}"; \
      mkdir -p /usr/local/share/ca-certificates; \
      if openssl x509 -in "${tmp}" -noout >/dev/null 2>&1; then \
        cp "${tmp}" /usr/local/share/ca-certificates/extra-ca.crt; \
      elif openssl x509 -inform DER -in "${tmp}" -out /usr/local/share/ca-certificates/extra-ca.crt >/dev/null 2>&1; then \
        true; \
      else \
        echo "Failed to parse EXTRA_CA_CERT_B64 as PEM or DER x509 cert" >&2; \
        exit 2; \
      fi; \
      update-ca-certificates; \
    fi

ARG MQ_VERSION="0.5.9"
RUN git clone --depth 1 --branch "v${MQ_VERSION}" https://github.com/harehare/mq.git /src/mq
WORKDIR /src/mq
RUN cargo install --locked --path crates/mq-run --root /opt/mq
RUN strip /opt/mq/bin/mq >/dev/null 2>&1 || true

# ----------------------------
# Runtime
# ----------------------------
FROM docker.io/library/node:20-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash ca-certificates curl git less openssh-client openssl \
    python3 python3-pip python3-venv \
    ripgrep \
    # Self-sufficient “skills/tooling” layer:
    # - image-crop: ImageMagick (convert/identify)
    # - read-pdf: Poppler tools (pdfinfo/pdftoppm) + ImageMagick is handy for follow-on crops
    # - read-webpage-content-as-markdown: curl + markitdown
    # - pandoc: document conversion
    imagemagick poppler-utils pandoc \
    # Needed for typst download/extract
    xz-utils \
    # Fonts for Typst output (minimal, broadly available)
    fontconfig fonts-dejavu \
  && rm -rf /var/lib/apt/lists/*

# Optional: add a corporate/WBG root CA for TLS interception environments.
# Pass it as base64 bytes (either PEM or DER) via build arg EXTRA_CA_CERT_B64.
ARG EXTRA_CA_CERT_B64=""
RUN if [ -n "${EXTRA_CA_CERT_B64}" ]; then \
      tmp=/tmp/extra-ca-cert.bin; \
      echo "${EXTRA_CA_CERT_B64}" | base64 -d > "${tmp}"; \
      mkdir -p /usr/local/share/ca-certificates; \
      if openssl x509 -in "${tmp}" -noout >/dev/null 2>&1; then \
        cp "${tmp}" /usr/local/share/ca-certificates/extra-ca.crt; \
      elif openssl x509 -inform DER -in "${tmp}" -out /usr/local/share/ca-certificates/extra-ca.crt >/dev/null 2>&1; then \
        true; \
      else \
        echo "Failed to parse EXTRA_CA_CERT_B64 as PEM or DER x509 cert" >&2; \
        exit 2; \
      fi; \
      update-ca-certificates; \
    fi

# Bring in mq from the builder stage.
COPY --from=mq_builder /opt/mq/bin/mq /usr/local/bin/mq

# Install Typst (prebuilt binary).
# We default to musl for portability (no external libc deps).
ARG TYPST_VERSION="0.14.2"
ARG TYPST_TARGET="x86_64-unknown-linux-musl"
RUN curl -fsSL \
      "https://github.com/typst/typst/releases/download/v${TYPST_VERSION}/typst-${TYPST_TARGET}.tar.xz" \
      -o /tmp/typst.tar.xz \
  && tar -xJf /tmp/typst.tar.xz -C /tmp \
  && install -m 0755 "/tmp/typst-${TYPST_TARGET}/typst" /usr/local/bin/typst \
  && rm -rf "/tmp/typst-${TYPST_TARGET}" /tmp/typst.tar.xz

# Install uv into a global location (so arbitrary --user UIDs can execute it).
RUN python3 -m pip install --no-cache-dir --break-system-packages uv

# read-webpage-content-as-markdown + read-pdf both rely on `markitdown`.
# Installing it in the image avoids depending on host uv-tool mounts.
RUN python3 -m pip install --no-cache-dir --break-system-packages "markitdown[pdf]"

# Force Node to use the OS CA store (including any EXTRA_CA_CERT_B64 we installed).
ENV NODE_OPTIONS="--use-openssl-ca"

# Install the Codex CLI.
# Allow overriding the npm registry (e.g., corporate mirror) and/or package spec.
ARG NPM_REGISTRY="https://registry.npmjs.org/"
ARG CODEX_NPM_PKG="@openai/codex@latest"
RUN npm config set registry "${NPM_REGISTRY}" \
  && npm config set cafile /etc/ssl/certs/ca-certificates.crt \
  && npm install -g "${CODEX_NPM_PKG}"

# Playwright + headless Chromium (for JS/client-rendered pages).
#
# Notes:
# - We install a system chromium as a fallback.
# - We also install Playwright and (by default) its bundled Chromium browser so
#   "playwright chromium" works out-of-the-box.
ARG INSTALL_PLAYWRIGHT_BROWSERS="1"
ARG PLAYWRIGHT_NPM_PKG="playwright@latest"
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
RUN apt-get update && apt-get install -y --no-install-recommends \
    chromium \
  && rm -rf /var/lib/apt/lists/*
RUN npm install -g "${PLAYWRIGHT_NPM_PKG}" \
  && if [ "${INSTALL_PLAYWRIGHT_BROWSERS}" = "1" ]; then \
       playwright install chromium; \
     fi

# Provide a predictable HOME for the wrapper (and make it writable for arbitrary UIDs).
ENV HOME=/home/codex
RUN mkdir -p "$HOME" && chmod 0777 "$HOME"
WORKDIR /home/codex
