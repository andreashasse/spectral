# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Spectral is an Elixir wrapper library for the Erlang `spectra` library. It provides idiomatic Elixir interfaces for type-driven JSON encoding/decoding, JSON Schema generation, and OpenAPI 3.1 specification generation.

## Development Commands

```bash
make test                        # Run all tests
mix test test/spectral_test.exs  # Run specific test file
mix test test/spectral_test.exs:42  # Run test at specific line
mix deps.update spectra          # Update the spectra dependency
```

Always run after any change:
```bash
make format && make ci
```

## Architecture

Spectral is a thin wrapper — implementation complexity lives in the Erlang `spectra` library. Each Spectral module wraps a corresponding Erlang module:

| Elixir | Erlang |
|---|---|
| `Spectral` | `:spectra` |
| `Spectral.OpenAPI` | `:spectra_openapi` |
| `Spectral.TypeInfo` | `:spectra_type_info` |
| `Spectral.Codec` | `:spectra_codec` (behaviour only) |
| `Spectral.Error` | `:sp_error` record conversion |

### `Spectral` (lib/spectral.ex)

Main API: `encode/4-5`, `decode/4-5`, `schema/3`, and bang variants. Also contains the `spectral/1` macro and `use Spectral` hook.

**`use Spectral`** injects `__spectra_type_info__/0` at compile time. This function reads the module's BEAM abstract code and enriches types and function specs with documentation from `@spectral` attributes. The pairing is by line number — each `spectral` call matches the next `@type` or `@spec` after it.

**`spectral/1` macro** accepts:
- For types: `title`, `description`, `examples`, `examples_function`, `type_parameters`
- For function specs: `summary`, `description`, `deprecated`

`type_parameters` is stripped before calling `:spectra_type.add_doc_to_type/2` (which would reject it) and applied separately to `meta.parameters` — this value is forwarded as the `params` argument to `Spectral.Codec` callbacks.

### `Spectral.Codec` (lib/spectral/codec.ex)

Behaviour for custom codec modules. Implement `encode/5`, `decode/5`, and optionally `schema/4`. The 2nd argument is the module that owns the type; the 5th argument (`params`) is the `type_parameters` value from the `spectral` attribute on the type, or `:undefined`.

`use Spectral.Codec` injects `@behaviour Spectral.Codec`. The Erlang library auto-detects codec modules by checking for `'Elixir.Spectral.Codec'` in the BEAM's `behaviour` attribute — no manual registration needed.

Return `:continue` for types the codec does not handle; `{:error, errors}` for bad data on types it owns.

### `Spectral.TypeInfo` (lib/spectral/type_info.ex)

Wraps `:spectra_type_info`. Key functions: `new/2`, `get_module/1`, `find_type/3`, `get_type/3`, `find_record/2`, `find_function/3`, `get_function_doc/3`.

### `Spectral.OpenAPI` (lib/spectral/openapi.ex)

Builder pattern for OpenAPI specs. Use `endpoint/2-5` then pipe through `add_response/2`, `with_request_body/3-4`, `with_parameter/3`, then `endpoints_to_openapi/2`.

`endpoint/5` reads function metadata from `module.__spectra_type_info__()` — the module must `use Spectral` and have a `spectral` annotation before the relevant `@spec`.

`with_request_body/4` — 4th argument is a `content_type` binary (e.g. `"application/xml"`). Description is sourced automatically from the type's `spectral` attribute.

## Key Conventions

- `Spectral.TypeInfo.new(:nomodule, false)` produces a blank type_info for use in tests.
- Test support modules live in `test/support/` and are compiled in `:test` env via `elixirc_paths`.

## Coverage

Use `cover_diff` to check for dead or untested code introduced by a change:

```bash
mix test --cover --export-coverage default
mix cover_diff --base-branch main
```

When adding new code, run `cover_diff` to confirm all new lines are exercised by tests. Uncovered lines in a diff are a signal to either add tests or remove dead code.
