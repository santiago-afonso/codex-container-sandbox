---
id: ccs-792f
status: closed
deps: []
links: []
created: 2026-01-12T21:38:50Z
type: bug
priority: 2
assignee: Santiago Afonso
---
# fix: auto-select working OCI runtime

Context: On some WSL/rootless Podman setups, the default OCI runtime (often 'crun') fails with 'crun: unknown version specified'. This breaks 'podman run' and 'podman build' for the sandbox image.

Approach: in the wrapper, auto-select an available runtime based on the environment (prefer runc on WSL; prefer crun on non-WSL), and pass an absolute runtime path to Podman so it cannot silently select a different `crun` binary via its own config search paths. Keep env override support.

Test plan:
- On a host where 'podman run --runtime crun' fails but '--runtime runc' succeeds, run: codex-container-sandbox --debug -- --version and confirm it uses runc.
- On a host where crun works, confirm it selects crun.
- Confirm CODEX_CONTAINER_SANDBOX_PODMAN_RUNTIME overrides auto-selection.

## Acceptance Criteria

- Wrapper selects a usable OCI runtime without manual flags.
- Respects CODEX_CONTAINER_SANDBOX_PODMAN_RUNTIME override (name or path).
- Always passes an absolute runtime path to Podman when a runtime is selected.


## Notes

**2026-01-12T21:44:16Z**

Implemented runtime auto-selection: wrapper now prefers runc on WSL and crun on non-WSL, with fallback based on availability; always passes absolute runtime paths so Podman doesn't pick a different crun via config search paths. Updated Makefile to default to runc on WSL when PODMAN_RUNTIME not set.
