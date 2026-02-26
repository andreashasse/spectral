# AGENTS.md

Guidance for agentic coding agents working in this repository.

## Project Overview

Spectral is a thin Elixir wrapper around the Erlang `:spectra` library. It provides:
- **Type-safe JSON encoding/decoding** via `Spectral.encode/4` and `Spectral.decode/4`
- **JSON Schema generation** via `Spectral.schema/3`
- **OpenAPI 3.0 spec generation** via `Spectral.OpenAPI`
- **Type documentation** via the `spectral/1` macro (`use Spectral`)

Most implementation complexity lives in `:spectra`/`:spectra_openapi`. Spectral's job is idiomatic Elixir delegation.

## Module Structure

| File | Purpose |
|---|---|
| `lib/spectral.ex` | Main API + `spectral/1` macro + `use Spectral` |
| `lib/spectral/openapi.ex` | OpenAPI builder API |
| `lib/spectral/error.ex` | `Spectral.Error` exception/struct |
| `lib/spectral/type_info.ex` | Internal type introspection helpers |
| `test/support/` | Fixture modules compiled only in test env |

## Build / Lint / Test Commands

```bash
# Full CI (must pass before committing)
make ci                          # compile + test + credo + dialyzer + format check

# Individual steps
make compile                     # mix compile --force --warnings-as-errors
make test                        # mix test
make credo                       # mix credo --strict
make type_check                  # mix dialyzer
make format                      # mix format  (auto-fix formatting)
make check_format                # mix format --check-formatted  (CI check, read-only)

# Run a single test file
mix test test/spectral_test.exs

# Run a single test by line number
mix test test/spectral_test.exs:45

# Run tests matching a name pattern
mix test --only "encode json"

# Interactive shell
make shell                       # iex -S mix

# Dependencies
mix deps.get
mix deps.update spectra
```

**Always run `make format` then `make ci` after any change.** Both must pass cleanly.

## Code Style

### Types and Specs
- Use `@type`, `@typep`, and `@typedoc` for all significant types.
- Prefer `dynamic()` (Erlang gradual typing convention) for runtime-determined return types.
- Use `iodata()` for encoded output types, not `binary()`.
- Spec public functions with full `@spec` before the `def`.
- Optional struct fields should be typed as `SomeType.t() | nil`.

### Error Handling
- Data validation errors: return `{:error, [%Spectral.Error{}]}` — never raise.
- Configuration/programming errors (bad module, missing type, unsupported type): raise `ArgumentError`.
- Use `with` for chaining operations that return `{:ok, _} | {:error, _}`.
- Convert Erlang errors via `Spectral.Error.from_erlang/1` or `from_erlang_list/1`.

### Imports and Dependencies
- Use `require Record` + `Record.extract(..., from_lib: "spectra/include/...")` — never hard-coded relative paths (`deps/...`).
- `from_lib:` resolves via `:code.lib_dir/1`; use it consistently in both lib and test files.
- Test fixtures that need Erlang records must also use `from_lib:`.

### Macros
- The `spectral/1` macro captures `__CALLER__.line` to pair documentation with the next `@type`.
- Place `spectral(...)` before (not necessarily immediately before) the `@type` it documents.
- `use Spectral` registers `@spectral` (accumulating), imports `spectral/1`, and injects `__spectra_type_info__/0`.
- `__before_compile__` pairs `@spectral` attributes with `@type`/`@typep` by line number.

### OpenAPI Builder Pattern
- Always use the fluent pipe-based builder: `endpoint/2` → `with_*` → `add_response/2`.
- For OpenAPI schema generation, type refs must be `{:type, :t, 0}` tuples, not plain atoms.
- For encode/decode/schema, plain atoms like `:t` are fine as `type_ref`.

## Testing Conventions

- Test files live in `test/` and are named `*_test.exs`.
- Support/fixture modules live in `test/support/` and are compiled via `elixirc_paths(:test)`.
- Fixture modules must have `@moduledoc false`.
- Use `doctest Spectral` in `SpectralTest` — keep doctest examples accurate.
- Prefer `assert {:ok, expected} == actual` style assertions.
