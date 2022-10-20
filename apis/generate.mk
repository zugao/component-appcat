clean_targets += .clean-apis

.PHONY: generate-xrd
generate-xrd: ## Generates the XRDs using Kubebuilder
	@rm -rf apis/generated
	@cd apis && go run sigs.k8s.io/controller-tools/cmd/controller-gen paths=./... crd:crdVersions=v1 output:artifacts:config=./generated
	@cd apis && go generate ./...
.clean-apis:
	rm -rf apis/generated
