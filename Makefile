MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:

include Makefile.vars.mk

.PHONY: help
help: ## Show this help
	@grep -E -h '\s##\s' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = "(: ).*?## "}; {gsub(/\\:/,":", $$1)}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: lint_jsonnet
lint_jsonnet: ## Lint jsonnet files
	cd component && $(MAKE) $@

.PHONY: lint_yaml
lint_yaml: ## Lint yaml files
	$(YAMLLINT_DOCKER) -f parsable -c $(YAMLLINT_CONFIG) $(YAMLLINT_ARGS) -- .

.PHONY: lint_adoc
lint_adoc: ## Lint documentation
	$(VALE_CMD) $(VALE_ARGS)
.PHONY: lint_kubent
lint_kubent: ## Check for deprecated Kubernetes API versions
	$(KUBENT_DOCKER) $(KUBENT_ARGS) -f $(KUBENT_FILES)

.PHONY: docs-serve
docs-serve: ## Preview the documentation
	$(ANTORA_PREVIEW_CMD)

gen-golden-all: ## For Renovate
	cd component && $(MAKE) $@
