# codex-container-sandbox

A Podman wrapper that runs `codex` inside a container and always uses:

- `--dangerously-bypass-approvals-and-sandbox` (the actual “yolo” behavior)
- `--sandbox danger-full-access`
- `--enable web_search_request` (web search tool available to the agent)

Networking is enabled (full egress).

## Quick start

### 1) Build an image

You need an image that includes `codex`, `git`, `bash`, `python3`, and `uv`.
Use `Containerfile`:

```bash
podman build -t localhost/codex-container-sandbox:latest -f Containerfile .
```

Or use the Makefile (also installs the wrapper):

```bash
make install
```

If you're on a corporate network with an npm mirror, override the registry:

```bash
make install NPM_REGISTRY=https://your-registry.example.com/
```

If TLS is intercepted (transparent proxy / self-signed in chain), pass a corporate root CA cert:

```bash
make install EXTRA_CA_CERT_PATH=$HOME/wbg_root_ca_g2.cer
```

If `~/wbg_root_ca_g2.cer` exists, the Makefile auto-detects it when
`EXTRA_CA_CERT_PATH` is not set.

You can also override bundled tool versions:

```bash
make install MQ_VERSION=0.5.9 TYPST_VERSION=0.14.2 TYPST_TARGET=x86_64-unknown-linux-musl
```

If you want a smaller build (skip Playwright’s bundled browser download), set:

```bash
make install INSTALL_PLAYWRIGHT_BROWSERS=0
```

### 2) Install the wrapper

```bash
install -m 0755 ./codex-container-sandbox ~/.local/bin/codex-container-sandbox
```

### 3) (Optional) Configure mounts

Create `~/.config/codex-container-sandbox/config.sh`:

```bash
CODEX_CONTAINER_SANDBOX_IMAGE="localhost/codex-container-sandbox:latest"

# Optional: force an OCI runtime (useful on some WSL/work setups).
# CODEX_CONTAINER_SANDBOX_PODMAN_RUNTIME="runc"

# Mount helper tools read-only (mapped under /home/codex/...)
CODEX_CONTAINER_SANDBOX_RO_MOUNTS=(
  "$HOME/.local/bin"
  "$HOME/bin"
)

# Persist caches if needed
CODEX_CONTAINER_SANDBOX_RW_MOUNTS=(
  "$HOME/.cache/uv"
  "$HOME/tmp"
)
```

## Usage

### Full network (default)

```bash
codex-container-sandbox exec "Summarize the repo"
```

### Makefile helpers

From the repo root:

```bash
make image
make selftest
make pii-scan
make validate-docs
```

### Self-test (network + mount isolation)

Runs three checks:

1. Container has internet connectivity.
2. Host files outside the workspace are not visible by default.
3. An explicitly mounted host directory is readable and writable (RW mount).

```bash
./selftest.sh
```

### Shell inside container

```bash
codex-container-sandbox --shell
```

### Debug the podman command

```bash
CODEX_CONTAINER_SANDBOX_DEBUG=1 codex-container-sandbox exec "hello"
```

### Hide the printed `codex ...` command

By default the wrapper prints the computed `codex ...` command (to stderr) before starting.
Disable with:

```bash
codex-container-sandbox --no-print-codex-cmd exec "hello"
```

## Mount behavior

- If you run inside a git repo, the **repo root** is mounted read-write.
- The container working directory is set to your original `$PWD` inside that mount.
- Extra mounts under `$HOME` are mapped to the same relative path under `/home/codex`.
- `XDG_CACHE_HOME` is set to `$CODEX_HOME/cache` so tools like `uv` have a writable cache by default.

## Auth

Codex credentials live in `CODEX_HOME` (`~/.local/state/codex-container-sandbox` by default).
Login once inside the container:

```bash
codex-container-sandbox --shell
codex login
```

### Reuse host auth.json (optional)

If you already have a working host login (for example `~/.codex/auth.json`), you can mount it
into the container so `codex` doesn't prompt for login again:

- Auto-detects and mounts `~/.codex/auth.json` if it exists.
- Override the path with `CODEX_CONTAINER_SANDBOX_AUTH_FILE=/path/to/auth.json`.
- Disable mounting entirely with `CODEX_CONTAINER_SANDBOX_DISABLE_AUTH_MOUNT=1`.
- Control mount mode (default `ro`) with `CODEX_CONTAINER_SANDBOX_AUTH_MOUNT_MODE=ro|rw`.

### Reuse host prompts and skills (optional)

To keep prompts and skills consistent with your host setup, the wrapper can also mount:

- `~/.codex/prompts` -> `$CODEX_HOME/prompts` (read-only)
- `~/.codex/skills` -> `$CODEX_HOME/skills` (read-only)

Controls:

- Override paths:
  - `CODEX_CONTAINER_SANDBOX_PROMPTS_DIR=/path/to/prompts`
  - `CODEX_CONTAINER_SANDBOX_SKILLS_DIR=/path/to/skills`
- Disable:
  - `CODEX_CONTAINER_SANDBOX_DISABLE_PROMPTS_MOUNT=1`
  - `CODEX_CONTAINER_SANDBOX_DISABLE_SKILLS_MOUNT=1`

### Reuse host helper CLIs (read-pdf)

If you have `read-pdf` installed on the host at `~/.local/bin/read-pdf`, the wrapper will
mount `~/.local/bin` read-only into the container so `read-pdf` (and its companion scripts)
are available on the container `$PATH`.

Disable with:

```bash
CODEX_CONTAINER_SANDBOX_DISABLE_LOCAL_BIN_MOUNT=1 codex-container-sandbox ...
```

### Built-in tools (image is self-sufficient)

The image ships with a few common “skills dependencies” so you don’t need host mounts:

- `imagemagick` (`convert`, `identify`) for `image-crop`
- `poppler-utils` (`pdfinfo`, `pdftoppm`) for `read-pdf --as-images`
- `markitdown` for `read-webpage-content-as-markdown` and `read-pdf --as-text-fast`
- `pandoc`
- `mq`
- `typst`
- `chromium` + `playwright` (JS/client-rendered pages)

### Reuse host CLIs (optional; for extra tools/versions)

If you install CLIs on the host via:

- `uv tool install ...` (often creates symlinks under `~/.local/bin` pointing at `~/.local/share/uv/tools/...`)
- Homebrew on Linux (e.g., `/home/linuxbrew/.linuxbrew/bin/...`)

the wrapper can mount the needed host directories read-only so those tools work inside the container.

Defaults (best-effort, only when detected):

- Mount `~/.local/share/uv/tools` read-only when `ttok` is detected as a uv tool install.
- Also mount `~/.local/share/uv/python` read-only (needed for uv tool shebang interpreters) when present.
- Mount `/home/linuxbrew/.linuxbrew` read-only when one of `yq` or `jq` is detected under that prefix, and add its `bin/` to `$PATH`.

Disable:

```bash
CODEX_CONTAINER_SANDBOX_DISABLE_UV_TOOLS_MOUNT=1 codex-container-sandbox ...
CODEX_CONTAINER_SANDBOX_DISABLE_UV_PYTHON_MOUNT=1 codex-container-sandbox ...
CODEX_CONTAINER_SANDBOX_DISABLE_HOMEBREW_MOUNT=1 codex-container-sandbox ...
```

Override Homebrew prefix:

```bash
CODEX_CONTAINER_SANDBOX_HOMEBREW_PREFIX=/some/other/prefix codex-container-sandbox ...
```

## Security note

This wrapper is about **filesystem isolation** (mount boundaries), not egress safety.
Because this runs full yolo with full networking, the agent can exfiltrate anything it can
read inside the container (including anything you mount, and `CODEX_HOME/auth.json`).
