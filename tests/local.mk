
kind_dir ?= $(PWD)/.kind
kind_bin = $(go_bin)/kind

crossplane_sentinel = $(kind_dir)/crossplane_sentinel
registry_sentinel = $(kind_dir)/registry_sentinel

cloudscale_version = $(shell yq -e '.parameters."pkg.appcat.provider.cloudscale".images.provider-cloudscale.tag' packages/provider/cloudscale.yml)
exoscale_version = master

golden_folder = packages/tests/golden

.PHONY: local-install
local-install: export KUBECONFIG = $(KIND_KUBECONFIG)
local-install: crossplane-setup install-crds

.PHONY: crossplane-setup
crossplane-setup: $(crossplane_sentinel) ## Installs Crossplane in kind cluster.

$(crossplane_sentinel): export KUBECONFIG = $(KIND_KUBECONFIG)
$(crossplane_sentinel): $(KIND_KUBECONFIG)
	helm repo add crossplane https://charts.crossplane.io/stable
	helm upgrade --install crossplane crossplane/crossplane \
		--create-namespace \
		--namespace crossplane-system \
		--set "args[0]='--debug'" \
		--set "args[1]='--enable-composition-revisions'" \
		--set webhooks.enabled=true \
		--wait
	kubectl apply -f tests/clusterrolebinding-crossplane.yaml
	@touch $@

.PHONY: install-crds
install-crds: export KUBECONFIG = $(KIND_KUBECONFIG)
install-crds: kind-setup # install cloudscale and exoscale CRDs
	@kubectl apply -f "https://raw.githubusercontent.com/vshn/provider-cloudscale/"$(cloudscale_version)"/package/crds/cloudscale.crossplane.io_buckets.yaml"
	@kubectl apply -f "https://raw.githubusercontent.com/vshn/provider-cloudscale/"${cloudscale_version}"/package/crds/cloudscale.crossplane.io_objectsusers.yaml"
	@kubectl apply -f "https://raw.githubusercontent.com/vshn/provider-exoscale/"${exoscale_version}"/package/crds/exoscale.crossplane.io_buckets.yaml"
	@kubectl apply -f "https://raw.githubusercontent.com/vshn/provider-exoscale/"${exoscale_version}"/package/crds/exoscale.crossplane.io_iamkeys.yaml"

.exoscale-composition:
	$(MAKE)	.prepare-integration-tests -e instance=exoscale

.cloudscale-composition:
	$(MAKE)	.prepare-integration-tests -e instance=cloudscale

.PHONY: .prepare-integration-tests
.prepare-integration-tests:
	rm -rf .cache compiled dependencies vendor
	cp $(golden_folder)/composite-objectstorage-$(instance)/appcat/appcat/composites.yaml tests/kuttl/$(instance)-status-test/00-install-$(instance)-composite.yaml
	yq e '.spec.writeConnectionSecretsToNamespace = "default"' $(golden_folder)/composition-objectstorage-$(instance)/appcat/appcat/compositions.yaml > tests/kuttl/$(instance)-status-test/00-install-$(instance)-composition.yaml

.PHONY: generate-integration-compositions
generate-integration-compositions: export KUBECONFIG = $(KIND_KUBECONFIG)
generate-integration-compositions: .cloudscale-composition .exoscale-composition

##
### Integration Tests
### with KUTTL (https://kuttl.dev)
###

kuttl_bin = $(go_bin)/kubectl-kuttl
$(kuttl_bin): export GOBIN = $(go_bin)
$(kuttl_bin): | $(go_bin)
	go install github.com/kudobuilder/kuttl/cmd/kubectl-kuttl@latest

test-integration: export KUBECONFIG = $(KIND_KUBECONFIG)
test-integration: $(kuttl_bin) local-install generate-integration-compositions
	GOBIN=$(go_bin) $(kuttl_bin) test ./tests/kuttl --config ./tests/kuttl/kuttl-test.yaml
	@rm -f kubeconfig
# kuttle leaves kubeconfig garbage: https://github.com/kudobuilder/kuttl/issues/297

.PHONY: kuttl-clean
kuttl-clean:
	rm -rf $(kuttl_bin)
