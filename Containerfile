FROM docker.io/library/node:20-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash ca-certificates curl git less openssh-client \
    python3 python3-pip python3-venv \
    ripgrep \
  && rm -rf /var/lib/apt/lists/*

# Install uv into a global location (so arbitrary --user UIDs can execute it).
RUN python3 -m pip install --no-cache-dir --break-system-packages uv

# Install the Codex CLI.
RUN npm install -g @openai/codex@latest

# Provide a predictable HOME for the wrapper (and make it writable for arbitrary UIDs).
ENV HOME=/home/codex
RUN mkdir -p "$HOME" && chmod 0777 "$HOME"
WORKDIR /home/codex
