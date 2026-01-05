.PHONY: help image install install-wrapper selftest pii-scan validate-docs

PODMAN ?= podman
PODMAN_RUNTIME ?= runc

IMAGE ?= localhost/codex-container-sandbox:latest
NPM_REGISTRY ?= https://registry.npmjs.org/
CODEX_NPM_PKG ?= @openai/codex@latest
EXTRA_CA_CERT_PATH ?=

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
	@extra_ca_arg=""; \
	if [ -n "$(EXTRA_CA_CERT_PATH)" ]; then \
		if [ ! -r "$(EXTRA_CA_CERT_PATH)" ]; then \
			echo "EXTRA_CA_CERT_PATH is set but not readable: $(EXTRA_CA_CERT_PATH)" >&2; \
			exit 2; \
		fi; \
		extra_ca_b64="$$(base64 -w 0 "$(EXTRA_CA_CERT_PATH)" 2>/dev/null || base64 "$(EXTRA_CA_CERT_PATH)" | tr -d '\n')"; \
		extra_ca_arg="--build-arg EXTRA_CA_CERT_B64=$$extra_ca_b64"; \
	fi; \
	"$(PODMAN)" build --runtime "$(PODMAN_RUNTIME)" \
		$$extra_ca_arg \
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
