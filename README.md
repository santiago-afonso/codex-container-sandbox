# codex-container-sandbox

A Podman wrapper that runs `codex` inside a container and always uses:

- `--dangerously-bypass-approvals-and-sandbox` (the actual “yolo” behavior)
- `--sandbox danger-full-access`

Networking is enabled (full egress).

## Quick start

### 1) Build an image

You need an image that includes `codex`, `git`, `bash`, `python3`, and `uv`.
Use `codex-container-sandbox/Containerfile`:

```bash
podman build -t localhost/codex-container-sandbox:latest -f codex-container-sandbox/Containerfile codex-container-sandbox
```

### 2) Install the wrapper

```bash
install -m 0755 codex-container-sandbox/codex-container-sandbox ~/.local/bin/codex-container-sandbox
```

### 3) (Optional) Configure mounts

Create `~/.config/codex-container-sandbox/config.sh`:

```bash
CODEX_CONTAINER_SANDBOX_IMAGE="localhost/codex-container-sandbox:latest"

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

### Shell inside container

```bash
codex-container-sandbox --shell
```

### Debug the podman command

```bash
CODEX_CONTAINER_SANDBOX_DEBUG=1 codex-container-sandbox exec "hello"
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

## Security note

This wrapper is about **filesystem isolation** (mount boundaries), not egress safety.
Because this runs full yolo with full networking, the agent can exfiltrate anything it can
read inside the container (including anything you mount, and `CODEX_HOME/auth.json`).
