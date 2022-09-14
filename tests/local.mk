
kind_dir ?= $(PWD)/.kind
kind_bin = $(go_bin)/kind

crossplane_sentinel = $(kind_dir)/crossplane_sentinel
registry_sentinel = $(kind_dir)/registry_sentinel

provider_cloudscale_version ?= $(shell yq -e '.parameters."pkg.appcat.provider.cloudscale".images.provider-cloudscale.tag' packages/provider/cloudscale.yml)
provider_exoscale_version ?= $(shell yq -e '.parameters."pkg.appcat.provider.exoscale".images.provider-exoscale.tag' packages/provider/exoscale.yml)
provider_kubernetes_version ?= $(shell yq -e '.parameters."pkg.appcat.provider.kubernetes".images.provider-kubernetes.tag' packages/provider/kubernetes.yml)

golden_dir = packages/tests/golden

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
install-crds: kind-setup ## Install CRDs of providers in kind cluster.
	@kubectl apply \
		-f "https://raw.githubusercontent.com/vshn/provider-cloudscale/$(provider_cloudscale_version)/package/crds/cloudscale.crossplane.io_buckets.yaml" \
		-f "https://raw.githubusercontent.com/vshn/provider-cloudscale/$(provider_cloudscale_version)/package/crds/cloudscale.crossplane.io_objectsusers.yaml" \
		-f "https://raw.githubusercontent.com/vshn/provider-exoscale/$(provider_exoscale_version)/package/crds/exoscale.crossplane.io_buckets.yaml" \
		-f "https://raw.githubusercontent.com/vshn/provider-exoscale/$(provider_exoscale_version)/package/crds/exoscale.crossplane.io_iamkeys.yaml" \
		-f "https://raw.githubusercontent.com/crossplane-contrib/provider-kubernetes/$(provider_kubernetes_version)/package/crds/kubernetes.crossplane.io_objects.yaml" \

.exoscale-composition:
	$(MAKE) .prepare-integration-tests -e instance=exoscale

.cloudscale-composition:
	$(MAKE) .prepare-integration-tests -e instance=cloudscale

.PHONY: .prepare-integration-tests
.prepare-integration-tests:
	rm -rf .cache compiled dependencies vendor
	cp $(golden_dir)/composite-objectstorage-$(instance)/appcat/appcat/composites.yaml tests/kuttl/$(instance)-status-test/00-install-$(instance)-composite.yaml
	yq e '.spec.writeConnectionSecretsToNamespace = "default"' $(golden_dir)/composition-objectstorage-$(instance)/appcat/appcat/compositions.yaml > tests/kuttl/$(instance)-status-test/00-install-$(instance)-composition.yaml

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
test-integration: $(kuttl_bin) local-install generate-integration-compositions ## Run integration tests with kuttl
	GOBIN=$(go_bin) $(kuttl_bin) test ./tests/kuttl --config ./tests/kuttl/kuttl-test.yaml
	@rm -f kubeconfig
# kuttl leaves kubeconfig garbage: https://github.com/kudobuilder/kuttl/issues/297

.PHONY: kuttl-clean
kuttl-clean:
	rm -rf $(kuttl_bin)
