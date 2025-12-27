.PHONY: help image install selftest pii-scan validate-docs

IMAGE ?= localhost/codex-container-sandbox:latest

help:
	@echo "codex-container-sandbox"
	@echo
	@echo "Targets:"
	@echo "  image          Build the container image (IMAGE=$(IMAGE))"
	@echo "  install        Install wrapper to ~/.local/bin"
	@echo "  selftest       Run network + mount isolation self-test"
	@echo "  pii-scan       Scan repo for common secret/PII patterns"
	@echo "  validate-docs  Validate README paths for standalone repo use"

image:
	podman build -t "$(IMAGE)" -f Containerfile .

install:
	install -m 0755 ./codex-container-sandbox ~/.local/bin/codex-container-sandbox

selftest:
	./selftest.sh

pii-scan:
	./scripts/pii_scan.sh

validate-docs:
	./scripts/validate_docs.sh

