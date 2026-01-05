# AGENTS.md (codex-container-sandbox)

This repo is vendored as a **git submodule** inside `~/dotfiles/` at:
- `~/dotfiles/codex-container-sandbox`

It provides a `codex-container-sandbox` wrapper that runs the OpenAI Codex CLI inside a Podman container, with a small and intentional set of host mounts to:
- keep the “yolo + web search” experience reproducible
- keep host exposure bounded and mostly read-only by default
- make selected host CLIs/skills available inside the container

## Core Intent

- The container is the execution environment for Codex.
- The host contributes *only* the workspace + a curated set of configuration/tooling mounts.
- Prefer portable, repeatable patterns (scripted in the wrapper + `make install`) over “manual one-off fixes”.

## Portability Workflow (repeatable)

When a new tool/skill is added on the host and you want it usable inside the container, follow this sequence:

1) **Decide: install in image vs mount from host**
   - Prefer **install in image** when the tool is lightweight, stable, and commonly needed.
   - Prefer **mount from host** when the tool is:
     - frequently changing
     - user-specific (auth/config)
     - already managed by a host toolchain (Homebrew / `uv tool`)
     - hard to package cleanly without distro-specific pain

2) **Mount host config safely (read-only by default)**
   - Mount host `~/.codex/auth.json` into container `$CODEX_HOME/auth.json` as **read-only** by default.
   - Mount host `~/.codex/prompts` and `~/.codex/skills` into container `$CODEX_HOME/prompts|skills` as **read-only** overlays.
   - Provide env toggles to disable any mount (so “clean room” runs are easy).

3) **Make host CLIs resolve inside the container**
   - If the host CLI lives in `~/.local/bin`, mount `~/.local/bin` read-only and ensure it is on PATH in-container.
   - If the host CLI is a symlink created by `uv tool` (common), it may depend on:
     - `~/.local/share/uv/tools`
     - `~/.local/share/uv/python`
     Mount those directories read-only into the container at the **same absolute paths** so symlinks/shebangs resolve.
   - If the host CLI is installed via Homebrew, mount the Homebrew prefix read-only (default `/home/linuxbrew/.linuxbrew`) so ELF deps and RPATHs keep working.

4) **Handle enterprise TLS / proxy environments**
   - If network is transparently MITM’d, language tooling (notably Node/npm) may not trust the system CA by default.
   - Keep a path to inject extra CAs into the image build (e.g. build-arg with base64-encoded cert), so npm/curl/git can validate TLS without insecure flags.

5) **Keep runtime portable across WSL/Linux**
   - Podman OCI runtime may differ by host; on WSL, `crun` can fail in some setups.
   - Prefer auto-selecting a known-good runtime (default to `runc` on WSL) with an override env var for advanced users.

6) **Make installation repeatable**
   - `make install` should:
     - build (or update) the container image
     - install/update a single stable wrapper entrypoint in `~/.local/bin`
     - avoid duplicate symlinks and be safe to re-run

## Agent Memory

- 2026-01-05: This repo is a git submodule under `~/dotfiles/codex-container-sandbox`.
- 2026-01-05: Portability pattern: mount host auth/prompts/skills RO; mount `~/.local/bin`, `uv` tool dirs, and Homebrew prefix RO when needed.
- 2026-01-05: Enterprise TLS MITM requires explicit CA injection during image build; avoid insecure npm/curl flags.
- 2026-01-05: WSL portability: default Podman runtime to `runc` (override via env) when `crun` is flaky.
