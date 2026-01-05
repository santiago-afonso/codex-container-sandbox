.PHONY: help image install install-wrapper selftest pii-scan validate-docs

PODMAN ?= podman
PODMAN_RUNTIME ?= runc

IMAGE ?= localhost/codex-container-sandbox:latest
NPM_REGISTRY ?= https://registry.npmjs.org/
CODEX_NPM_PKG ?= @openai/codex@latest

PREFIX ?= $(HOME)/.local
BINDIR ?= $(PREFIX)/bin

help:
	@echo "codex-container-sandbox"
	@echo
	@echo "Targets:"
	@echo "  image          Build the container image (IMAGE=$(IMAGE))"
	@echo "  install        Build image + symlink wrapper into ~/.local/bin"
	@echo "  install-wrapper  Symlink wrapper into ~/.local/bin (no image build)"
	@echo "  selftest       Run network + mount isolation self-test"
	@echo "  pii-scan       Scan repo for common secret/PII patterns"
	@echo "  validate-docs  Validate README paths for standalone repo use"

image:
	@command -v "$(PODMAN)" >/dev/null 2>&1 || { echo "$(PODMAN) not found on PATH" >&2; exit 1; }
	"$(PODMAN)" build --runtime "$(PODMAN_RUNTIME)" \
		--build-arg NPM_REGISTRY="$(NPM_REGISTRY)" \
		--build-arg CODEX_NPM_PKG="$(CODEX_NPM_PKG)" \
		-t "$(IMAGE)" -f Containerfile .

install: image install-wrapper

install-wrapper:
	@mkdir -p "$(BINDIR)"
	@ln -sfn "$(CURDIR)/codex-container-sandbox" "$(BINDIR)/codex-container-sandbox"
	@echo "Installed: $(BINDIR)/codex-container-sandbox -> $(CURDIR)/codex-container-sandbox"

selftest:
	./selftest.sh

pii-scan:
	./scripts/pii_scan.sh

validate-docs:
	./scripts/validate_docs.sh
