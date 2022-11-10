# Commodore Component: appcat

This is a [Commodore][commodore] Component for appcat.

This repository is part of Project Syn.
For documentation on Project Syn and this component, see https://syn.tools.

## Getting started for developers

This repository contains:

* `packages`: SYN Commodore "packages" (which are actually just bundles of SYN configuration files, no code)
  * `composite`: SYN Configuration containing the user-facing Crossplane/K8s kind "ObjectBucket"
  * `composition`: SYN Configuration containing the Crossplane "composition", which translates between the user-facing K8s kind "ObjectBucket" and Crossplane's internal K8s kinds "Bucket" and "ObjectsUser"
* `component`: SYN Commodore component for installing AppCat features
* `apis`: The code that describes the Composites (XRDs) and generates their YAML in `/packages/composite/`

This component can be compiled with commodore like this:

```
$ cd component
$ commodore component compile . --search-paths . -n appcat -f tests/defaults.yml
#
# Alternative:
#
$ cd component
$ make test
```

The resulting compiled component can be found in `component/compiled/`.

There is currently no easy way to run it locally. You need to apply the compiled component to a test cluster to see if it works as expected.

This process is not suitable for installing the component on a production system. In order to do that please follow the documentation found in the next paragraph.

## Integration Testing with Kuttl

Some packages are tested with the Kubernetes E2E testing tool [Kuttl](https://kuttl.dev/docs).
Kuttl is basically comparing the installed manifests (usually files named `##-install*.yaml`) with observed objects and compares the desired output (files named `##-assert*.yaml`).

To execute tests, run `make test-integration` from the root dir.

The tests are executed in parallel to save test time, but it makes reading errors and output harder.
If a test fails, kuttl leaves the resources in the kind-cluster intact, so you can inspect the resources and events if necessary.
Please note that Kubernetes Events from cluster-scoped resources appear in the `default` namespace only, but `kubectl describe ...` should show you the events.

If tests succeed, the relevant resources are deleted to not use up costs on the cloud providers.

## Generate XRDs with Go / KubeBuilder

In `/apis` there is code in Go to generate the XRDs (composites) as this is in OpenAPI.
This code generates the OpenAPI scheme using [Kubebuilder](https://kubebuilder.io/).

See following pages for learning how to do that:
- https://kubebuilder.io/reference/generating-crd.html
- https://kubebuilder.io/reference/markers.html

To run the composition generator, run `make generate-xrd generate-integration-compositions`.
You need to have `go` installed for this to work.

After that, you are able to update the golden files for the packages: `make gen-golden-packages`.

## Documentation

The rendered documentation for this component is available on the [Commodore Components Hub](https://hub.syn.tools/appcat).

Documentation for this component is written using [Asciidoc][asciidoc] and [Antora][antora].
It is located in the [docs/](docs) folder.
The [Divio documentation structure](https://documentation.divio.com/) is used to organize its content.

Run the `make docs-serve` command in the root of the project, and then browse to http://localhost:2020 to see a preview of the current state of the documentation.

After writing the documentation, please use the `make lint_adoc` command and correct any warnings raised by the tool.

## Contributing and license

This library is licensed under [BSD-3-Clause](LICENSE).
For information about how to contribute see [CONTRIBUTING](CONTRIBUTING.md).

[commodore]: https://syn.tools/commodore/
[asciidoc]: https://asciidoctor.org/
[antora]: https://antora.org/
