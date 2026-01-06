# SANDBOX_CONTAINER_DOCUMENTATION_AND_INSTRUCTIONS.md

This file is intentionally placed in the **workspace** (the repo root) so that an agent running inside `codex-container-sandbox` can read it from inside the container mount.

## What environment am I running in?

You are running inside a **Podman container** launched by the `codex-container-sandbox` wrapper script.

Key points:
- The wrapper runs Codex in **full yolo mode** with networking enabled.
- Only a bounded set of host paths are mounted into the container (primarily the git workspace + optional RO helper mounts).
- The container working directory is set to the same path as your host `$PWD`, but under the container’s workspace mount.

## WSL / Podman prerequisites (host-side)

If you are running on **WSL2**, modern Podman works best with:

- **systemd enabled** in the distro
- **cgroups-v2 (unified cgroup hierarchy) enabled**

If you see warnings like “Using cgroups-v1 … deprecated”, or errors around missing runtimes, fix the host setup first.

Recommended Windows-side command (PowerShell, from the `os_scripts` repo):

- `windows\\wsl_setup_ubuntu_2404.ps1 -EnableSystemd -EnableCgroupV2 -ShutdownAfter`

Then rebuild the image if needed:

- `cd ~/dotfiles/codex-container-sandbox && make install`

## Where should I write artifacts?

Write all temporary artifacts to:

- `{workspace}/tmp`

Concretely:
- Use `./tmp/...` relative to the repo root whenever possible.
- Do **not** write to OS temp directories like `/tmp` unless explicitly required; container `/tmp` is ephemeral and harder to discover from the repo.

### Default `tmp/` structure (use these folders)

The wrapper pre-creates these folders on the host (if missing) and attempts to keep them out of `git status`
by adding `tmp/` to `.git/info/exclude` (repo-local, uncommitted).

Use these folders and place files in the most specific bucket:

- `{workspace}/tmp/codex-container-sandbox/` — wrapper + agent preflight outputs / logs (JSONL streams, debug, repro scripts)
- `{workspace}/tmp/fetched/web/` — webpages and derived snapshots
  - `{workspace}/tmp/fetched/web/raw/` — raw HTML fetches (source-of-truth inputs)
  - `{workspace}/tmp/fetched/web/markdown/` — derived markdown, cleaned HTML, etc.
- `{workspace}/tmp/fetched/pdf/` — PDFs and PDF-derived artifacts
  - `{workspace}/tmp/fetched/pdf/raw/` — downloaded PDFs (source-of-truth inputs)
  - `{workspace}/tmp/fetched/pdf/pages/` — rendered page images (e.g., via `pdftoppm`)
  - `{workspace}/tmp/fetched/pdf/text/` — extracted text (e.g., via `pdftotext`)
- `{workspace}/tmp/fetched/images/` — images and image-derived artifacts
  - `{workspace}/tmp/fetched/images/raw/` — downloaded images (PNG/JPG/SVG, etc.)
  - `{workspace}/tmp/fetched/images/derived/` — crops, conversions, OCR outputs, etc.
- `{workspace}/tmp/fetched/other/` — any other fetched/binary inputs (ZIPs, data dumps, etc.)
  - `{workspace}/tmp/fetched/other/raw/` — original downloads
  - `{workspace}/tmp/fetched/other/derived/` — unpacked or processed outputs

Notes:
- Prefer deterministic, descriptive filenames (include domain/date/slug when practical).
- Keep any “processed” artifacts next to the input folder when it’s clearly tied to a specific fetch (e.g. rendered PDF pages under `tmp/fetched/pdf/<doc-stem>/pages/`).

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
