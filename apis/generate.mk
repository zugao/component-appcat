clean_targets += .clean-apis

.PHONY: generate-xrd
generate-crd: ## Generates the CRDs using Kubebuilder, these CRDs will be used as a base for the XRDs by the component
	@rm -rf apis/generated
	@cd apis && go run sigs.k8s.io/controller-tools/cmd/controller-gen paths=./... crd:crdVersions=v1 output:artifacts:config=./generated
	@cd apis && go run sigs.k8s.io/controller-tools/cmd/controller-gen object paths=./...
	@cd apis && go generate ./...
	@rm -rf crds && cp -r apis/generated crds
.clean-apis:
	rm -rf apis/generated
