# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v0.4.1

- Makes error messages more informative when unable to convert strings to integers or floats

## v0.4.0

- Adds support for custom transformer types by allowing an arity 1 function as the second argument to `Dotenvy.Transformer.to/2`. See [Issue 2](https://github.com/fireproofsocks/dotenvy/issues/2)

## v0.3.0

- Renames `Dotenvy.Transformer.to/2` to `Dotenvy.Transformer.to!/2` to better communicate that it may raise an error.
- Returns key name in errors for easier troubleshooting.
- Tracks an error if the `:require_files` option lists a file not included in the `files` input (for sanity).
- Introduces `Dotenvy.env!/3` (which is the same as `Dotenvy.env/3` but with no defaults provided). This better communicates that it may raise an error (because internally it relies on `Dotenvy.Transformer.to!/2`)
- Deprecates `Dotenvy.env/3` in favor of `Dotenvy.env!/3`

## v0.2.0

Adds support for default `type` of `:string` to the `Dotenvy.env!/2` and `Dotenvy.env/3` functions.

## v0.1.0

Initial release.
