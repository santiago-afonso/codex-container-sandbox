---
id: ccs-52e4
status: closed
deps: []
links: []
created: 2026-01-06T19:13:30Z
type: task
priority: 2
assignee: Santiago Afonso
---
# Install tk (wedow/ticket) in container image

Context: Codex agent workflow expects the local ticket tracker (tk) to exist inside the container so agents can create and manage .tickets/ without relying on host mounts.

Test plan:
- make image
- podman run --rm <image> tk --help
- podman run --rm <image> tk create 'smoke' && tk ls

## Acceptance Criteria

- Container image contains the wedow/ticket script exposed as both 'tk' and 'ticket' on PATH.
- Building via make image succeeds with no Homebrew dependency.
- A minimal podman run smoke-check confirms 'tk --help' works.
