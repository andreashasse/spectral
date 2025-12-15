# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
