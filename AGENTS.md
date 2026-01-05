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

## In-Workspace Agent Documentation

This repo includes `SANDBOX_CONTAINER_DOCUMENTATION_AND_INSTRUCTIONS.md` (at repo root).

Rules:
- Keep it **current** whenever you change mount behavior, tool availability, or any “where to write artifacts” convention.
- The file must remain readable from inside the container workspace mount (i.e., it must live in the repo root and be committed).
- The file must instruct agents to write temporary artifacts under `{workspace}/tmp` (repository-local), not OS `/tmp`.

## Keeping The Image Up To Date

This image intentionally vendors multiple fast-moving tools. To keep it maintainable:

- Prefer putting versions behind **ARG defaults** in `Containerfile` with corresponding `Makefile` variables, so updates are one-line changes.
- For each pinned tool, decide update cadence:
  - `uv` + default Python: update regularly (Python point releases, uv releases).
  - `codex` npm package: keep `@latest` (already); regressions should be handled by overriding `CODEX_NPM_PKG`.
  - `playwright`: keep `@latest` by default; be aware it downloads large browser artifacts.
  - `typst`, `mq`, `bd`: update occasionally; pin versions to known-good releases but revisit when bugs/features require it.
- When bumping versions:
  - Rebuild the image via `make image` (or `make install`) on a corporate network (to catch TLS/proxy issues early).
  - Run a minimal in-container smoke check: `python3 --version`, `uv --version`, `codex --version`, `playwright --version`, and any key CLIs (pdf/image/web).
  - Update `SANDBOX_CONTAINER_DOCUMENTATION_AND_INSTRUCTIONS.md` if behavior/tooling changes.

## Corporate TLS Workarounds (host-specific)

- This repo supports building with an extra corporate root CA via `EXTRA_CA_CERT_PATH`.
- Auto-detection of `~/wbg_root_ca_g2.cer` is intentionally restricted to the WBG laptop hostname (`PCACL-G7MKN94`).
- Do not enable corporate CA injection or related TLS workarounds by default on non-corporate machines (e.g., home networks).

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
- 2026-01-05: Keep `SANDBOX_CONTAINER_DOCUMENTATION_AND_INSTRUCTIONS.md` updated; agents write artifacts under `{workspace}/tmp`.
- 2026-01-05: Corporate CA auto-detect only on host `PCACL-G7MKN94`; home builds must not inject WBG CA by default.
