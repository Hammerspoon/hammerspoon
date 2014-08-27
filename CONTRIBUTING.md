## Filing bug reports or feature requests

You may want to discuss it on the mailing list first.

## Contributing your own extensions

Follow the pattern set by [core.window](https://github.com/mjolnir-io/mjolnir.core.window).

The basics:

- It's best to clone an existing extension to start with, but you should also be aware of minimum extension requirements.
- An extension requires *at least* an `init.lua` file.
- An extension's name should be prefixed (i.e. `sd.grid`).
- To contribute an extension, submit a pull request containing a foldre in the pattern of `ext/your.extension/` in [mjolnir-ext](https://github.com/mjolnir-io/mjolnir-ext) containing the files `docs.json` and `metadata.json`.
- See existing `{docs,metadata}.json` files for examples of what they should contain.

Also please follow these version guidelines:

1. Extensions versioned `0.x` are "UNSTABLE" meaning their APIs **MAY** break backwards compatibility.
2. Extensions versioned `0.x` may depend on any other extensions.
3. Extensions versioned `1.x` or greater are "STABLE" meaning their APIs **MAY NOT** break backwards compatibility.
4. Extensions versioned `1.x` or greater may **ONLY** depend on STABLE extensions.

More details will come soon, perhaps with a sample extension.
