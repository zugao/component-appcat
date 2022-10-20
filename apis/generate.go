//go:build generate

// Remove existing manifests
//go:generate rm -rf ./generated

// Generate deepcopy methodsets and CRD manifests
//go:generate go run -tags generate sigs.k8s.io/controller-tools/cmd/controller-gen paths=./... crd:crdVersions=v1 output:artifacts:config=./generated

package apis
