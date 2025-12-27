#!/usr/bin/env bash
set -euo pipefail

echo "[validate-docs] Validating README for standalone repo paths..."

bad=0

# These are common mistakes when the repo is vendored under ./codex-container-sandbox/.
if rg -n -S 'codex-container-sandbox/Containerfile' README.md >/dev/null; then
  echo "[validate-docs] README.md references codex-container-sandbox/Containerfile; use Containerfile at repo root." >&2
  bad=1
fi

if rg -n -S 'codex-container-sandbox/codex-container-sandbox' README.md >/dev/null; then
  echo "[validate-docs] README.md references codex-container-sandbox/codex-container-sandbox; use ./codex-container-sandbox." >&2
  bad=1
fi

if [[ "$bad" -ne 0 ]]; then
  exit 1
fi

echo "[validate-docs] PASS"

