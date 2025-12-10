# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Spectral is an Elixir wrapper library for the Erlang `spectra` library (v0.1.9). It provides idiomatic Elixir interfaces for:
- **Data encoding/decoding**: Convert Elixir structs to/from JSON using type specifications
- **Schema generation**: Generate JSON schemas from Elixir type definitions
- **OpenAPI specification**: Generate OpenAPI 3.0 specifications from type definitions

The library leverages Elixir's type system to automatically handle serialization based on struct type definitions.

## Architecture

The codebase has a simple three-module structure:

1. **`Spectral`** (lib/spectral.ex): Main API module providing wrapper functions for:
   - `encode/4` - Converts Elixir data structures to specified formats (e.g., JSON)
   - `decode/4` - Parses data from formats into Elixir structures
   - `schema/3` - Generates schemas (e.g., JSON Schema) from type definitions

   All functions delegate to the underlying `:spectra` Erlang library.

2. **`Spectral.OpenAPI`** (lib/spectral/openapi.ex): OpenAPI 3.0 specification generation, wrapping `:spectra_openapi`. Uses a builder pattern:
   - Response builders: `response/2`, `response_with_body/3-4`, `response_with_header/4`
   - Endpoint builders: `endpoint/2`, `add_response/2`, `with_request_body/3-4`, `with_parameter/3`
   - Spec generation: `endpoints_to_openapi/2`

   Example:
   ```elixir
   response = Spectral.OpenAPI.response(200, "Success")
     |> Spectral.OpenAPI.response_with_body(Person, {:type, :t, 0})

   endpoint = Spectral.OpenAPI.endpoint(:get, "/users/{id}")
     |> Spectral.OpenAPI.add_response(response)
   ```

3. **`Person`** (lib/person.ex): Example/test module demonstrating usage patterns with nested structs.

### Type-Driven Design

The library works by reading Elixir `@type` specifications from modules (e.g., `Person.t()`) and using them to drive encoding, decoding, and schema generation. When adding new functionality, ensure modules have proper type specs defined.

**Important**: For OpenAPI schema generation, type references must use the explicit tuple format `{:type, :t, 0}` instead of just `:t`. This is because the OpenAPI generator needs to resolve type information differently than the encoder/decoder.

## Development Commands

### Testing
```bash
mix test                    # Run all tests
mix test test/spectral_test.exs  # Run specific test file
mix test --only line:9      # Run test at specific line
```

The test suite includes doctests from module documentation, so ensure examples in `@doc` blocks are correct.

### Code Quality
```bash
mix format                  # Format code according to .formatter.exs
mix format --check-formatted # Check if code is formatted
```

### Dependencies
```bash
mix deps.get                # Fetch dependencies
mix deps.update spectra     # Update the spectra dependency
```

### Build
```bash
mix compile                 # Compile the project
```

### Documentation
```bash
mix docs                    # Generate HTML documentation (requires ex_doc dependency)
```

## Working with This Codebase

- The library is a thin Elixir wrapper, so most implementation complexity lives in the underlying Erlang `spectra` library
- When adding new wrapper functions, follow the existing pattern of simple delegation to `:spectra` or `:spectra_openapi`
- Type specifications must be defined with `@type` for the library to work with structs
- Nil values in structs are automatically omitted during JSON encoding (see test examples)
- Always run make format and then make ci after a change