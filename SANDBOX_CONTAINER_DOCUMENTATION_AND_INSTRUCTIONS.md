# SANDBOX_CONTAINER_DOCUMENTATION_AND_INSTRUCTIONS.md

This file is intentionally placed in the **workspace** (the repo root) so that an agent running inside `codex-container-sandbox` can read it from inside the container mount.

## What environment am I running in?

You are running inside a **Podman container** launched by the `codex-container-sandbox` wrapper script.

Key points:
- The wrapper runs Codex in **full yolo mode** with networking enabled.
- Only a bounded set of host paths are mounted into the container (primarily the git workspace + optional RO helper mounts).
- The container working directory is set to the same path as your host `$PWD`, but under the container’s workspace mount.

## Where should I write artifacts?

Write all temporary artifacts to:

- `{workspace}/tmp`

Concretely:
- Use `./tmp/...` relative to the repo root whenever possible.
- Do **not** write to OS temp directories like `/tmp` unless explicitly required; container `/tmp` is ephemeral and harder to discover from the repo.

This includes:
- rendered PDF page images
- extracted markdown
- intermediate JSON/JSONL
- debug dumps and repro scripts

## Tooling available in the container (common)

The container image aims to be largely self-sufficient for common skills:
- PDF triage: `pdfinfo`, `pdftoppm`
- Image manipulation: `convert`, `identify`
- Webpage → markdown: `curl`, `markitdown`
- Document conversions: `pandoc`
- Markdown AST query: `mq`
- Typesetting: `typst`
- Browser automation: `playwright`, `chromium` (headless)
- Local issue tracking: `bd` (Beads)
- Python is **uv-managed** and exposed as `python3` (default target: Python 3.14.x)

## Certificates / corporate TLS interception

On some corporate networks, TLS is transparently intercepted (MITM) and requires a corporate root CA to be trusted.

This container supports injecting a corporate CA **at image build time** (e.g., via `make install EXTRA_CA_CERT_PATH=...`).

The image also sets common environment variables so tools prefer the system CA bundle:
- `SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt`
- `REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt`
- `GIT_SSL_CAINFO=/etc/ssl/certs/ca-certificates.crt`
- `CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt`

## Safety / scope reminders

- Treat the workspace as sensitive (it may include credentials and private content).
- Prefer read-only mounts for host configuration (auth, prompts, skills) unless you explicitly need to write.
- If you need a clean working tree for a commit, do **not** revert user edits; stash/unstash as needed and keep commits narrowly scoped.
