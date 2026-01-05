.PHONY: help image install install-wrapper selftest pii-scan validate-docs

PODMAN ?= podman
PODMAN_RUNTIME ?= runc

IMAGE ?= localhost/codex-container-sandbox:latest
# NOTE: Some corporate networks MITM/TLS-intercept npmjs.org in ways that
# manifest as ECONNRESET. The npmjs.com alias often behaves better.
NPM_REGISTRY ?= https://registry.npmjs.com/
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
	extra_ca_path="$(EXTRA_CA_CERT_PATH)"; \
	if [ -z "$$extra_ca_path" ] && [ -r "$$HOME/wbg_root_ca_g2.cer" ]; then \
		extra_ca_path="$$HOME/wbg_root_ca_g2.cer"; \
		echo "Auto-detected EXTRA_CA_CERT_PATH=$$extra_ca_path" >&2; \
	fi; \
	if [ -n "$$extra_ca_path" ]; then \
		if [ ! -r "$$extra_ca_path" ]; then \
			echo "EXTRA_CA_CERT_PATH is set but not readable: $$extra_ca_path" >&2; \
			exit 2; \
		fi; \
		extra_ca_b64="$$(base64 -w 0 "$$extra_ca_path" 2>/dev/null || base64 "$$extra_ca_path" | tr -d '\n')"; \
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
