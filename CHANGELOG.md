# Changelog

## v0.1.0

Initial release.

## v0.2.0

Adds support for default `type` of `:string` to the `Dotenvy.env!/2` and `Dotenvy.env/3` functions.

## v0.3.0

- Renames `Dotenvy.Transformer.to/2` to `Dotenvy.Transformer.to!/2` to better communicate that it may raise an error.
- Returns key name in errors for easier troubleshooting.
- Tracks an error if the `:require_files` option lists a file not included in the `files` input (for sanity).
- Introduces `Dotenvy.env!/3` (which is the same as `Dotenvy.env/3` but with no defaults provided). This better communicates that it may raise an error (because internally it relies on `Dotenvy.Transformer.to!/2`)
- Deprecates `Dotenvy.env/3` in favor of `Dotenvy.env!/3`
