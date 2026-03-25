 # Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.9.0] - 2026-03-25

### Added
- `Spectral.Type` module with `type_args/1` — extracts concrete type-variable bindings from the `sp_type` argument passed to codec callbacks, enabling codecs to recursively encode/decode generic types
- `deprecated` is now a documented `spectral` field for types — marks a type as deprecated, emitted as `"deprecated": true` in the generated JSON Schema
- `examples_function` added to the `spectral/1` macro `@doc` and `use Spectral` moduledoc

### Changed
- **BREAKING**: `Spectral.Codec` callbacks changed from 5-arg to 6-arg. A new `sp_type` argument is inserted as the 5th argument (before `params`) in `encode/6`, `decode/6`, and `schema/5`. Update all codec implementations by adding a `_sp_type` parameter before `params` in every callback clause.
- `Spectral.Codec.MapSet` for `MapSet.t(elem)` now recursively encodes, decodes, and generates schemas for each element according to its type, using `Spectral.Type.type_args/1`
- `spectral/1` macro `@doc` split into separate `@type` and `@spec` field sections, so function spec fields (`summary`, `description`, `deprecated`) are now documented on the macro itself
- Upgraded spectra dependency to `~> 0.9.0`

## [0.8.1] - 2026-03-21

### Added
- `Spectral.schema/4` — accepts an options list as the last argument, supporting the `:pre_encoded` option to return a map instead of iodata
- `Spectral.OpenAPI.endpoints_to_openapi/3` — accepts an options list, supporting the same `:pre_encoded` option
- `schema_option/0` type for the new options

### Changed
- Upgraded spectra dependency from `~> 0.8.0` to `~> 0.8.1`
- `Spectral.OpenAPI` specs now use precise exported spectra types (`endpoint_spec`, `response_spec`, `openapi_metadata`, etc.) instead of `dynamic()` / `map()`
- README revised: requirements merged into installation, sections reordered, Options table added, string/binary constraints documented, `examples_function` documented

## [0.8.0] - 2026-03-19

### Added
- `Spectral.Codec` behaviour for custom serialization/deserialization — implement `encode/5`, `decode/5`, and optionally `schema/4` to handle any type
- Built-in codecs for common Elixir types: `Spectral.Codec.DateTime`, `Spectral.Codec.Date`, and `Spectral.Codec.MapSet`
- `type_parameters` key in `spectral` attribute — passes a static value to codec callbacks as the `params` argument, enabling one codec to handle multiple type variants

### Changed
- **BREAKING**: `Spectral.OpenAPI.with_request_body/4` — the fourth argument reverted from an opts map back to a `content_type :: binary()` string; description is now sourced automatically from the type's `spectral` attribute. Update calls from `with_request_body(e, mod, schema, %{content_type: "application/xml"})` to `with_request_body(e, mod, schema, "application/xml")`.
- Upgraded spectra dependency to `~> 0.8.0`

### Removed
- **BREAKING**: `Spectral.TypeInfo.new/0` removed — use `new(module, false)` instead

## [0.7.0] - 2026-03-04

### Added
- `Spectral.OpenAPI.with_request_body/4` now accepts an opts map as the fourth argument with optional `content_type` and `description` keys
- `parameter_spec` in `Spectral.OpenAPI.with_parameter/3` now supports `description` and `deprecated` fields
- `header_spec` in `Spectral.OpenAPI.response_with_header/4` now supports a `deprecated` field
- `endpoints_to_openapi/2` metadata now supports additional `info` fields (`summary`, `description`, `terms_of_service`, `contact`, `license`) and a top-level `servers` list

### Changed
- **BREAKING**: `Spectral.OpenAPI.with_request_body/4` — the fourth argument changed from a `content_type :: binary()` string to an `opts :: map()`. Update calls from `with_request_body(e, mod, schema, "application/xml")` to `with_request_body(e, mod, schema, %{content_type: "application/xml"})`.
- Upgraded spectra dependency from `~> 0.6.0` to `~> 0.7.0`

## [0.6.0] - 2026-03-04

### Added
- `spectral/1` macro can now be placed before `@spec` definitions to attach endpoint documentation (`summary`, `description`, `deprecated`) to functions
- `Spectral.TypeInfo.get_function_doc/3` — retrieves endpoint documentation stored in a function's `sp_function_spec` metadata; returns `{:ok, doc}`, `{:error, :no_doc_found}`, or `{:error, :function_not_found}`
- `Spectral.OpenAPI.endpoint/5` — 5-argument overload that reads a function's `spectral/1` metadata from the module's type info and uses it as the OpenAPI operation documentation; raises `ArgumentError` if the function has no `spectral/1` annotation

### Changed
- Upgraded spectra dependency from `~> 0.5.1` to `~> 0.6.0`
- spectra 0.6.0 fixes the `sp_union` record default value (no user-facing impact)

## [0.5.1] - 2026-03-02

### Added
- `opts` parameter to `encode/5`, `decode/5`, `encode!/5`, and `decode!/5` for passing options to the underlying spectra library (backward-compatible: defaults to `[]`)
- `:pre_encoded` option for `encode/5`/`encode!/5`: returns intermediate JSON term (map/list) instead of iodata
- `:pre_decoded` option for `decode/5`/`decode!/5`: accepts an already-decoded JSON term as input, skipping JSON parsing

### Changed
- Upgraded spectra dependency from 0.5.0 to 0.5.1
- spectra 0.5.1 adds performance improvements via `persistent_term` caching for `__spectra_type_info__/0` calls

## [0.5.0] - 2026-02-26

### Added
- `spectral/1` annotation macro for documenting `@type`/`@typep` definitions with JSON Schema metadata (title, description, examples)
- `Spectral.TypeInfo` module for runtime type introspection via `__spectra_type_info__/0`
- OpenAPI endpoint documentation support via type annotations

## [0.4.0] - 2026-01-27

### Changed
- Upgraded spectra dependency from 0.3.2 to 0.4.0
- **BREAKING CHANGE**: `Spectral.schema/3` now returns `iodata()` directly instead of `{:ok, iodata()}` tuple, matching the new spectra 0.4.0 API

### Removed
- **BREAKING CHANGE**: Removed `Spectral.schema!/3` function as it's no longer needed (schema/3 now returns directly)

## [0.3.2] - 2026-01-25

### Changed
- Upgraded spectra dependency from 0.3.1 to 0.3.2
- Added Erlang/OTP 27+ requirement to documentation (required by spectra)
- Added documentation section explaining extra fields handling during JSON decoding

## [0.3.1] - 2026-01-25

### Changed
- Upgraded spectra dependency from 0.3.0 to 0.3.1
- Improved type specifications to use `dynamic()` instead of `term()` for runtime-determined types
- Updated project documentation to remove hardcoded dependency version references

## [0.3.0] - 2026-01-20

### Changed
- Upgraded spectra dependency from 0.2.0 to 0.3.0
- JSON Schema generation now uses JSON Schema 2020-12 (previously draft-07)
- OpenAPI specification generation now produces OpenAPI 3.1 (previously 3.0)
- Improved error messages and handling of remote types in enums and parameterized types
- Better documentation of null/optional field handling

## [0.2.0] - 2025-12-15

### Changed
- Extra fields in JSON objects are now silently ignored during decoding, allowing for forward compatibility

## [0.1.4] - 2025-12-13

### Changed
- Both missing fields and explicit `null` values in JSON now decode to `nil` for optional struct fields

## [0.1.3] - 2025-12-13

### Changed
- Support for Elixir 1.18
- Cleanup hex release configuration
- Exclude person example files from release package

## [0.1.2] - 2025-12-12

### Changed
- Make Spectral more idiomatic
- Improve API to be pipe-friendly
- Better error handling
- Update README documentation

## [0.1.1] - 2025-12-10

### Changed
- Better documentation
- Fix hex docs

## [0.1.0] - 2025-11-08

### Added
- Initial release
- Type-driven JSON encoding/decoding
- JSON Schema generation from Elixir type definitions
- OpenAPI 3.0 specification generation
- Wrapper for Erlang spectra library
- Support for nested structs
- Automatic nil value omission in JSON encoding
