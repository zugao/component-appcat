root_volume     ?= -v "$${PWD}/:/component"

PROJECT_ROOT_DIR = .
PROJECT_NAME ?= component-appcat
PROJECT_OWNER ?= vshn

ifneq "$(shell which docker 2>/dev/null)" ""
	DOCKER_CMD    ?= $(shell which docker)
	DOCKER_USERNS ?= ""
else
	DOCKER_CMD    ?= podman
	DOCKER_USERNS ?= keep-id
endif
DOCKER_ARGS ?= run --rm -u "$$(id -u):$$(id -g)" --userns=$(DOCKER_USERNS) -w /component -e HOME="/component"

YAMLLINT_ARGS   ?= --no-warnings
YAMLLINT_CONFIG ?= .yamllint.yml
YAMLLINT_IMAGE  ?= docker.io/cytopia/yamllint:latest
YAMLLINT_DOCKER ?= $(DOCKER_CMD) $(DOCKER_ARGS) $(root_volume) $(YAMLLINT_IMAGE)

VALE_CMD  ?= $(DOCKER_CMD) $(DOCKER_ARGS) $(root_volume) --volume "$${PWD}"/docs/modules:/pages docker.io/vshn/vale:2.1.1
VALE_ARGS ?= --minAlertLevel=error --config=/pages/ROOT/pages/.vale.ini /pages

ANTORA_PREVIEW_CMD ?= $(DOCKER_CMD) run --rm --publish 35729:35729 --publish 2020:2020 --volume "${PWD}/.git":/preview/antora/.git --volume "${PWD}/docs":/preview/antora/docs docker.io/vshn/antora-preview:3.0.1.1 --style=syn --antora=docs
GOLDEN_FILES    ?= $(shell find component/tests/golden/$(instance) -type f)

KUBENT_FILES    ?= $(shell echo "$(GOLDEN_FILES)" | sed 's/ /,/g')
KUBENT_ARGS     ?= -c=false --helm2=false --helm3=false -e
# Use our own kubent image until the upstream image is available
KUBENT_IMAGE    ?= docker.io/projectsyn/kubent:latest
KUBENT_DOCKER   ?= $(DOCKER_CMD) $(DOCKER_ARGS) $(root_volume) --entrypoint=/app/kubent $(KUBENT_IMAGE)

instance ?= defaults
test_instances = tests/defaults.yml

# https://hub.docker.com/r/kindest/node/tags
KIND_NODE_VERSION ?= v1.24.0
KIND_IMAGE ?= docker.io/kindest/node:$(KIND_NODE_VERSION)
KIND_KUBECONFIG ?= $(kind_dir)/kind-kubeconfig-$(KIND_NODE_VERSION)
KIND_CLUSTER ?= $(PROJECT_NAME)-$(KIND_NODE_VERSION)

go_bin ?= $(PWD)/.work/bin
$(go_bin):
	@mkdir -p $@
