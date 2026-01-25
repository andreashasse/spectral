 # Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.2] - 2026-01-25

### Changed
- Upgraded spectra dependency from 0.3.1 to 0.3.2
- Added Erlang/OTP 27+ requirement to documentation (required by spectra)

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
