# Commodore Component: appcat

This is a [Commodore][commodore] Component for appcat.

This repository is part of Project Syn.
For documentation on Project Syn and this component, see https://syn.tools.

## Getting started for developers

This component can be compiled with commodore like this:

```
$ cd component
$ commodore component compile -n appcat .
```

The resulting compiled component can be found in `component/compiled/`.

There is currently no easy way to run it locally. You need to apply the compiled component to a test cluster to see if it works as expected.

This process is not suitable for installing the component on a production system. In order to do that please follow the documentation found in the next paragraph.

## Documentation

The rendered documentation for this component is available on the [Commodore Components Hub](https://hub.syn.tools/appcat).

Documentation for this component is written using [Asciidoc][asciidoc] and [Antora][antora].
It is located in the [docs/](docs) folder.
The [Divio documentation structure](https://documentation.divio.com/) is used to organize its content.

Run the `make docs-serve` command in the root of the project, and then browse to http://localhost:2020 to see a preview of the current state of the documentation.

After writing the documentation, please use the `make docs-vale` command and correct any warnings raised by the tool.

## Contributing and license

This library is licensed under [BSD-3-Clause](LICENSE).
For information about how to contribute see [CONTRIBUTING](CONTRIBUTING.md).

[commodore]: https://syn.tools/commodore/
[asciidoc]: https://asciidoctor.org/
[antora]: https://antora.org/
