---
id: ccs-9f4a
status: closed
deps: []
links: []
created: 2026-01-06T20:17:00Z
type: task
priority: 2
assignee: santi
---
# Add Copilot CLI in sandbox image

Context: Agents run inside `codex-container-sandbox` and need GitHub Copilot CLI available in-image. We keep Codex pinned to `@latest` by default, but allow overriding via build args when a specific version is needed.

Acceptance Criteria:
- Container installs `@github/copilot@prerelease` globally (CLI available as `copilot`).
- `make image` produces an image where `codex --version` and `copilot --help` run.
- If a specific Codex version is required, it can be built via `make image CODEX_NPM_PKG=@openai/codex@0.78`.

Test plan:
- `cd ~/dotfiles/codex-container-sandbox && make image`
- `podman run --rm localhost/codex-container-sandbox:latest codex --version`
- `podman run --rm localhost/codex-container-sandbox:latest copilot --help`
