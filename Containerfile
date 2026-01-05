FROM docker.io/library/node:20-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash ca-certificates curl git less openssh-client \
    python3 python3-pip python3-venv \
    ripgrep \
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

# Install uv into a global location (so arbitrary --user UIDs can execute it).
RUN python3 -m pip install --no-cache-dir --break-system-packages uv

# Install the Codex CLI.
# Allow overriding the npm registry (e.g., corporate mirror) and/or package spec.
ARG NPM_REGISTRY="https://registry.npmjs.org/"
ARG CODEX_NPM_PKG="@openai/codex@latest"
RUN npm config set registry "${NPM_REGISTRY}" \
  && npm config set cafile /etc/ssl/certs/ca-certificates.crt \
  && npm install -g "${CODEX_NPM_PKG}"

# Provide a predictable HOME for the wrapper (and make it writable for arbitrary UIDs).
ENV HOME=/home/codex
# Force Node to use the OS CA store (including any EXTRA_CA_CERT_B64 we installed).
ENV NODE_OPTIONS="--use-openssl-ca"
RUN mkdir -p "$HOME" && chmod 0777 "$HOME"
WORKDIR /home/codex
