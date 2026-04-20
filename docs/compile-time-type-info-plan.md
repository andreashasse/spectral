# Plan: Move `spectra_abstract_code` Work to Compile Time

## Problem Statement

Currently, `__spectra_type_info__/0` does expensive work at **runtime** every time it's called:

1. Locates the BEAM file path via `:code.which/1`
2. Calls `:spectra_abstract_code.types_in_module_path/1` which reads the BEAM file, parses abstract code, and converts all type/record/spec forms into `sp_type()` records
3. Applies spectral annotations (docs, `only`, `type_parameters`)
4. Applies function docs

All of this can be done at **compile time** in `__before_compile__`, with the final `#type_info{}` embedded as a constant in the generated function. The result: `__spectra_type_info__/0` becomes a simple constant return with near-zero runtime cost.

## Key Technical Question

The approach hinges on the format of `_type_expr` in the type attributes returned by `Module.get_attribute(env.module, :type)`:

```elixir
{kind, {:"::", meta, [{name, _, args_or_nil}, _type_expr]}, _env}
```

Currently `_type_expr` is **ignored** — the macro only extracts name, arity, and line number. The actual type conversion is deferred to runtime.

Based on how Elixir's compiler processes `@type` definitions (it translates quoted Elixir to Erlang abstract format before storing), the body should be in Erlang abstract format — the same format that `spectra_abstract_code.field_info_to_type/1` expects. **This must be verified in Phase 0.**

## Decisions

| Decision | Choice |
|---|---|
| Implementation approach | Extend spectra's API (export `field_info_to_type/1` + `type_from_form/1`) |
| Property-based testing | Yes — add StreamData |
| Backward compatibility | Clean break — no runtime fallback |
| Spectra dependency handling | Branch + git dep (publish hex release later) |

## Phase 0: Investigation — Determine Type/Spec Attribute Formats

**Goal:** Discover the exact format of `_type_expr` and spec expressions in module attributes at compile time.

### Actions

1. **Create `test/support/type_format_inspector.ex`** — a module with diverse type definitions (`integer()`, `%Struct{}`, `[atom()] | nil`, `String.t()`, `0..255`, `(integer() -> binary())`, parameterized types, etc.) that uses a custom `__before_compile__` to capture the raw `Module.get_attribute(env.module, :type)` and `Module.get_attribute(env.module, :spec)` entries into a module attribute accessible at runtime.

2. **Create `test/type_format_investigation_test.exs`** — a test that:
   - Reads the captured compile-time type attributes
   - Reads the BEAM file with `:beam_lib.chunks/2` to get the Erlang abstract forms
   - Prints/asserts the format comparison
   - Confirms whether the type bodies are already in Erlang abstract format

3. **Delete both files** after Phase 0 is complete.

### Expected Outcome

The type bodies are in Erlang abstract format, meaning we can reconstruct the abstract forms and feed them to spectra's `type_from_form/1`.

## Phase 1: Extend Spectra's API

**Repo:** Local spectra repo (create a branch, e.g. `export-type-form`)

### Changes to `spectra_abstract_code.erl`

1. **Export `field_info_to_type/1`** — the core conversion function (~200 lines, handles all Erlang type constructs: simple types, maps, structs, unions, tuples, lists, ranges, literals, remote types, user type refs, function types, etc.)

2. **Add and export `type_from_form/1`** — a higher-level function that takes a single Erlang abstract form and returns the typed result:

   ```erlang
   -spec type_from_form(erl_parse:abstract_form()) ->
       false | {true, type_form_result()}.
   ```

   This is essentially the existing internal `type_in_form/1` function, renamed and exported. It handles:
   - Type/opaque/nominal forms → `{{type, Name, Arity}, sp_type()}`
   - Record forms → `{{record, Name}, sp_rec()}`
   - Spec forms → `{{function, Name, Arity}, [sp_function_spec()]}`

3. **Export update:** Add to the existing `-export` directive:

   ```erlang
   -export([types_in_module/1, types_in_module_path/1, apply_only/2,
            field_info_to_type/1, type_from_form/1]).
   ```

### Mix.exs Update in Spectral

```elixir
# Temporarily point to git branch during development
{:spectra, github: "andreashasse/spectra", branch: "export-type-form"}
```

## Phase 2: Modify Spectral's `__before_compile__`

**File:** `lib/spectral.ex`

### 2a. Reconstruct Abstract Forms from Attributes

In `__before_compile__`, convert each type attribute back to the abstract form that `type_from_form/1` expects:

```elixir
# For each @type attribute:
{kind, {:"::", meta, [{name, _, args_or_nil}, type_expr]}, _env} ->
  line = Keyword.get(meta, :line, 0)
  args = args_or_nil || []
  # Reconstruct as: {:attribute, line, kind_atom, {name, type_expr, args}}
  form = {:attribute, line, kind, {name, type_expr, args}}
  case :spectra_abstract_code.type_from_form(form) do
    {true, {key, sp_type}} -> {key, sp_type, line}
    false -> nil
  end
```

Similarly for `@spec` attributes — reconstruct the Erlang spec form:

```elixir
# For each @spec attribute:
{:spec, spec_ast, _env} ->
  # Reconstruct as: {:attribute, line, :spec, {{name, arity}, [function_types]}}
  form = reconstruct_spec_form(spec_ast)
  case :spectra_abstract_code.type_from_form(form) do
    {true, {key, specs}} -> {key, specs}
    false -> nil
  end
```

### 2b. Detect Codec Behaviour

```elixir
behaviours = Module.get_attribute(env.module, :behaviour) || []
implements_codec = Spectral.Codec in behaviours or :spectra_codec in behaviours
```

### 2c. Build `type_info` at Compile Time

```elixir
base = :spectra_type_info.new(env.module, implements_codec)

# Add types
type_info =
  Enum.reduce(converted_types, base, fn {{:type, name, arity}, sp_type}, acc ->
    tagged = :spectra_type.update_meta(sp_type, %{name: {:type, name, arity}})
    :spectra_type_info.add_type(acc, name, arity, tagged)
  end)

# Add records (if any)
type_info =
  Enum.reduce(converted_records, type_info, fn {{:record, name}, sp_rec}, acc ->
    tagged = :spectra_type.update_meta(sp_rec, %{name: {:record, name}})
    :spectra_type_info.add_record(acc, name, tagged)
  end)

# Add function specs
type_info =
  Enum.reduce(converted_specs, type_info, fn {{:function, name, arity}, specs}, acc ->
    :spectra_type_info.add_function(acc, name, arity, specs)
  end)
```

### 2d. Apply Spectral Annotations at Compile Time

Move the existing runtime doc/only/type_parameters application into compile time. The pairing logic (matching `spectral` annotations to types/specs by line number) already runs at compile time — extend it to also **apply** the modifications:

```elixir
type_info =
  Enum.reduce(type_docs_to_add, type_info, fn {name, arity, doc}, acc ->
    case :spectra_type_info.find_type(acc, name, arity) do
      {:ok, existing_type} ->
        {type_params, doc1} = Map.pop(doc, :type_parameters)
        {only, doc_clean} = Map.pop(doc1, :only)

        updated =
          existing_type
          |> then(fn t ->
            if only != nil, do: :spectra_abstract_code.apply_only(t, only), else: t
          end)
          |> :spectra_type.add_doc_to_type(doc_clean)
          |> then(fn t ->
            if type_params != nil do
              meta = :spectra_type.get_meta(t)
              :spectra_type.set_meta(t, Map.put(meta, :parameters, type_params))
            else
              t
            end
          end)

        :spectra_type_info.add_type(acc, name, arity, updated)

      :error ->
        acc
    end
  end)
```

Same for function docs — apply `Spectral.__attach_function_doc__/4` at compile time.

### 2e. Emit as Constant

The generated function becomes trivial:

```elixir
quote do
  @doc false
  def __spectra_type_info__ do
    unquote(Macro.escape(final_type_info))
  end
end
```

**Before (runtime work):**
```elixir
def __spectra_type_info__ do
  beam_path = :code.which(__MODULE__) |> ...
  type_info = :spectra_abstract_code.types_in_module_path(beam_path)
  # ... apply docs, only, type_parameters ...
end
```

**After (compile-time constant):**
```elixir
def __spectra_type_info__ do
  {:type_info, MyModule, %{{:t, 0} => ...}, %{}, %{}, false}
end
```

## Phase 3: Testing

### 3a. Add StreamData Dependency

In `mix.exs`:

```elixir
{:stream_data, "~> 1.1", only: :test}
```

### 3b. Equivalence Tests — `test/type_info_equivalence_test.exs`

For every existing fixture module, compare the new compile-time result against what `spectra_abstract_code.types_in_module_path/1` would produce:

```elixir
@fixture_modules [
  Person, Person.Address, MultiTypeModule, MultiTypeModuleReversed,
  MultiTypeModuleFirstMissing, SemanticPairingTestModule,
  TypeWithParams, OnlyPerson, EndpointHandler, MultiSpectralHandler,
  DefaultValues, DefaultValues.Config, EctoUser
]

for mod <- @fixture_modules do
  test "#{inspect(mod)}: compile-time type_info matches runtime" do
    compile_time = unquote(mod).__spectra_type_info__()
    runtime = build_runtime_type_info(unquote(mod))
    assert compile_time == runtime
  end
end
```

The `build_runtime_type_info/1` helper calls `:spectra_abstract_code.types_in_module_path/1` and then applies the same doc annotations that `__before_compile__` applies, to produce the expected result for comparison.

### 3c. Comprehensive Type Coverage Fixture — `test/support/all_types_module.ex`

A new fixture module exercising every type construct that `field_info_to_type/1` handles:

```elixir
defmodule AllTypesModule do
  use Spectral

  # Simple types
  @type simple_int :: integer()
  @type simple_bin :: binary()
  @type simple_atom :: atom()
  @type simple_bool :: boolean()
  @type simple_float :: float()
  @type a_string :: String.t()
  @type a_term :: term()
  @type a_number :: number()

  # Predefined integer ranges
  @type a_non_neg :: non_neg_integer()
  @type a_pos :: pos_integer()
  @type a_neg :: neg_integer()

  # Explicit range
  @type a_range :: 0..255

  # Literals
  @type a_literal_atom :: :hello
  @type a_literal_nil :: nil

  # Union
  @type a_union :: integer() | binary() | nil

  # Lists
  @type a_list :: [integer()]
  @type a_nonempty_list :: nonempty_list(atom())

  # Tuples
  @type a_tuple :: {atom(), integer(), binary()}
  @type any_tuple :: tuple()

  # Maps
  @type a_typed_map :: %{atom() => integer()}

  # Struct map
  @type t :: %AllTypesModule{}

  # Remote types
  @type a_remote :: String.t()

  # User type ref
  @type a_user_ref :: simple_int()

  # Parameterized type
  @type a_param(a) :: %{value: a}

  # Function types
  @type a_fun :: (integer() -> binary())

  # Special types
  @type a_pid :: pid()
  @type an_iodata :: iodata()
  @type a_timeout :: timeout()
  @type an_mfa :: mfa()
  @type a_reference :: reference()
  @type a_port :: port()
end
```

### 3d. Property-Based Tests — `test/type_info_property_test.exs`

Using StreamData to dynamically create and compile modules with various type definitions:

```elixir
defmodule TypeInfoPropertyTest do
  use ExUnit.Case
  use ExUnitProperties

  property "compile-time type_info matches runtime for dynamically created modules" do
    check all type_def <- type_definition_generator(),
              max_runs: 100 do
      module_name = :"Elixir.PropTest_#{System.unique_integer([:positive])}"
      code = """
      defmodule #{inspect(module_name)} do
        use Spectral
        #{type_def}
      end
      """
      [{^module_name, _}] = Code.compile_string(code)

      compile_time = module_name.__spectra_type_info__()
      beam_path = :code.which(module_name)
      runtime = :spectra_abstract_code.types_in_module_path(beam_path)

      # Compare type structures (ignoring doc annotations since runtime has none)
      assert compile_time == runtime
    after
      :code.purge(module_name)
      :code.delete(module_name)
    end
  end

  # Generator producing valid @type definition strings
  defp type_definition_generator do
    simple_type =
      member_of([
        "integer()", "binary()", "atom()", "boolean()", "float()",
        "String.t()", "term()", "number()", "pid()", "reference()",
        "non_neg_integer()", "pos_integer()", "iodata()"
      ])

    one_of([
      # Simple type
      map(simple_type, &"@type t :: #{&1}"),
      # Union of two types
      map({simple_type, simple_type}, fn {a, b} ->
        "@type t :: #{a} | #{b}"
      end),
      # Union with nil
      map(simple_type, &"@type t :: #{&1} | nil"),
      # List type
      map(simple_type, &"@type t :: [#{&1}]"),
      # Tuple type
      map({simple_type, simple_type}, fn {a, b} ->
        "@type t :: {#{a}, #{b}}"
      end),
      # Map type
      map({simple_type, simple_type}, fn {a, b} ->
        "@type t :: %{optional(#{a}) => #{b}}"
      end)
    ])
  end
end
```

**Additional properties to test:**
- Type count in `type_info` matches number of `@type` definitions
- All type names are present in the `type_info`
- Module name in `type_info` matches the compiled module

### 3e. Existing Test Suite

All existing tests must continue to pass unchanged. Since they all go through `__spectra_type_info__/0`, they implicitly validate the compile-time approach.

## Phase 4: Cleanup and CI

1. Delete Phase 0 investigation files
2. Run `make format`
3. Run `make ci` — compile, test, credo, dialyzer, format check
4. Eventually: publish spectra with the new exports, switch Spectral back to hex dep

## Dependency Ordering

```
Phase 0 (investigation)
    │
    ▼
Phase 1 (extend spectra)  ← requires spectra branch
    │
    ▼
Phase 2 (modify __before_compile__)
    │
    ▼
Phase 3 (testing) — 3a-3c can start in parallel with Phase 2
    │
    ▼
Phase 4 (cleanup)
```

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| **Elixir version compatibility** — type attribute format may differ across versions | Project requires `~> 1.17`; only support 1.17+ |
| **Keeping in sync with spectra** — if `field_info_to_type/1` adds new type constructs | Equivalence tests will catch any drift immediately |
| **Macro.escape limits** — complex `#type_info{}` with many records | Should be fine — all record types are tuples of atoms/binaries/integers/maps |
| **Cover-compiled modules** — special handling needed? | Eliminated entirely — compile-time approach doesn't read BEAM files |
| **Records** — Erlang records aren't typical in Elixir modules | Verify in Phase 0; handle if needed, skip if not |

## Files Changed Summary

| File | Change |
|---|---|
| **spectra** `src/spectra_abstract_code.erl` | Export `field_info_to_type/1`, add+export `type_from_form/1` |
| `mix.exs` | Point spectra to git branch, add StreamData |
| `lib/spectral.ex` | Rewrite `__before_compile__` to build type_info at compile time |
| `test/support/all_types_module.ex` | **New** — comprehensive type coverage fixture |
| `test/type_info_equivalence_test.exs` | **New** — compile-time vs runtime comparison tests |
| `test/type_info_property_test.exs` | **New** — StreamData property tests |
