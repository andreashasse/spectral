# Plan: Move `spectra_abstract_code` Work to Compile Time

## Problem Statement

Currently, `__spectra_type_info__/0` does expensive work at **runtime** every time it's called:

1. Locates the BEAM file path via `:code.which/1`
2. Calls `:spectra_abstract_code.types_in_module_path/1` which reads the BEAM file, parses abstract code, and converts all type/record/spec forms into `sp_type()` records
3. Applies spectral annotations (docs, `only`, `type_parameters`)
4. Applies function docs

All of this can be done at **compile time** in `__before_compile__`, with the final `#type_info{}` embedded as a constant in the generated function. The result: `__spectra_type_info__/0` becomes a simple constant return with near-zero runtime cost.

## Phase 0 Findings (Completed)

Investigation ran via `test/type_format_investigation_test.exs` against `test/support/type_format_inspector.ex` (40 types, 3 specs, covering all type constructs).

### Finding 1: Compile-time type bodies are Elixir quoted AST (NOT Erlang abstract format)

All 40 types differed between compile-time and beam_lib. The compile-time `_type_expr` is **Elixir quoted AST**, not Erlang abstract format. The two formats are structurally different in every case.

**Consequence: We cannot feed compile-time attributes directly to `spectra_abstract_code.field_info_to_type/1`. We must write our own Elixir AST → sp_type() converter.**

**This means the decision to "Extend spectra's API" is revised** — we need to write an Elixir-side converter, not export an Erlang function.

### Finding 2: Mapping of Elixir AST → Erlang abstract format

The patterns are consistent and complete. Every Erlang abstract type form has a corresponding Elixir AST representation:

| Type | Elixir compile-time AST | Erlang abstract (beam_lib) |
|---|---|---|
| `integer()` | `{:integer, [line: N, col: C], []}` | `{:type, {N,C}, :integer, []}` |
| `binary()` | `{:binary, meta, []}` | `{:type, {N,C}, :binary, []}` |
| `atom()`, `boolean()`, etc. | `{:atom_name, meta, []}` | `{:type, {N,C}, :atom_name, []}` |
| `non_neg_integer()` | `{:non_neg_integer, meta, []}` | `{:type, {N,C}, :non_neg_integer, []}` |
| `0..255` (range) | `{:.., meta, [0, 255]}` | `{:type, {N,C}, :range, [{:integer,0,0},{:integer,0,255}]}` |
| `:hello` (atom literal) | `:hello` | `{:atom, 0, :hello}` |
| `nil` | `nil` | `{:atom, 0, nil}` |
| `true`/`false` | `true`/`false` | `{:atom, 0, true/false}` |
| `42` (integer literal) | `42` | `{:integer, 0, 42}` |
| `A \| B \| C` (union) | `{:\|, meta, [A, {\|, meta, [B, C]}]}` (right-nested) | `{:type, {N,C}, :union, [A, B, C]}` (flat list) |
| `[integer()]` (list shorthand) | `[{:integer, meta, []}]` (a 1-element list) | `{:type, 0, :list, [{:type,...,:integer,[]}]}` |
| `list()` | `{:list, meta, []}` | `{:type, {N,C}, :list, []}` |
| `nonempty_list(atom())` | `{:nonempty_list, meta, [{:atom,meta,[]}]}` | `{:type, {N,C}, :nonempty_list, [{:type,...,:atom,[]}]}` |
| `{atom(), integer()}` (tuple) | `{:{}, meta, [atom_ast, int_ast]}` | `{:type, {N,C}, :tuple, [atom_type, int_type]}` |
| `tuple()` (any tuple) | `{:tuple, meta, []}` | `{:type, {N,C}, :tuple, :any}` |
| `%{atom() => integer()}` (typed map) | `{:%{}, meta, [{atom_ast, int_ast}]}` | `{:type, {N,C}, :map, [{:type,...,map_field_exact,[atom_t,int_t]}]}` |
| `%{required(:name) => T, optional(:age) => T}` | `{:%{}, meta, [{{:required,meta,[:name]}, T_ast}, {{:optional,meta,[:age]}, T_ast}]}` | map_field_exact / map_field_assoc |
| `%Module{field: T}` (struct) | `{:%, meta, [aliases_ast, {:%{}, meta, [field: T_ast]}]}` | `{:type,...,:map,[__struct__ exact field, field1 exact,...]}` |
| `String.t()` (remote type) | `{{:., meta, [{:__aliases__,meta,[:String]}, :t]}, meta, []}` | `{:remote_type, {N,C}, [{:atom,0,String},{:atom,0,:t},[]]}`  |
| `keyword(integer())` (remote w/ args) | `{:keyword, meta, [{:integer,meta,[]}]}` | `{:remote_type, 0, [{:atom,0,:elixir},{:atom,0,:keyword},[int_type]]}` |
| `t_integer()` (user type ref) | `{:t_integer, meta, []}` | `{:user_type, {N,C}, :t_integer, []}` |
| `%{value: a}` (parameterized map) | `{:%{}, meta, [value: {:a, meta, nil}]}` | `{:type,...,:map,[map_field_exact [:value, {:var,...,:a}]]}` |
| `fun()` | `{:fun, meta, []}` | `{:type, {N,C}, :fun, []}` |
| `(integer() -> binary())` | `[{:->, meta, [[int_ast], bin_ast]}]` (a list with `->`) | `{:type,...,:fun,[{:type,...,:product,[int_t]}, bin_t]}` |
| `pid()`, `port()`, `reference()` | `{:pid, meta, []}` etc. | `{:type, {N,C}, :pid, []}` etc. |
| `iodata()`, `iolist()` | `{:iodata, meta, []}` etc. | `{:type, {N,C}, :iodata, []}` etc. |
| `timeout()`, `mfa()`, `identifier()` | `{:timeout, meta, []}` etc. | `{:type, {N,C}, :timeout, []}` etc. |

### Finding 3: Spec format

Compile-time `@spec` attributes are also **Elixir quoted AST**:

```elixir
# Simple spec: @spec simple_fun(integer(), binary()) :: boolean()
{:spec,
 {:"::", [line: 124, ...],
  [{:simple_fun, [...], [{:integer,[...],[]}, {:binary,[...],[]}]},
   {:boolean, [...], []}]},
 {Module, {124, 1}}}

# Bounded spec: @spec bounded_fun(a, b) :: a when a: integer(), b: binary()
{:spec,
 {:when, [...],
  [{:"::", [...], [{:bounded_fun, [...], [{:a,[...],nil}, {:b,[...],nil}]},
    {:a, [...], nil}]},
   [a: {:integer,[...],[]}, b: {:binary,[...],[]}]},
 {Module, {124, 1}}}
```

Multi-clause specs are stored as **separate attribute entries** (one per clause), ordered last-to-first (reversed).

### Finding 4: Revised implementation approach

Since the compile-time bodies are Elixir AST (not Erlang abstract format), we need to write an Elixir-side `Spectral.AbstractCode` module that converts Elixir type AST → `sp_type()` records directly. This replaces the original plan to extend spectra's Erlang API.

**Revised decisions:**

| Decision | Original | Revised |
|---|---|---|
| Core type conversion | Extend spectra's Erlang API | Write `Spectral.AbstractCode` in Elixir |
| Spectra dependency | Git branch + new exports | No changes to spectra needed |
| Spec for `type_from_form` | Export from Erlang | Implement natively in Elixir |

## Key Technical Question (Answered)

The approach hinges on the format of `_type_expr` in the type attributes returned by `Module.get_attribute(env.module, :type)`:

```elixir
{kind, {:"::", meta, [{name, _, args_or_nil}, _type_expr]}, _env}
```

**Answer: `_type_expr` is Elixir quoted AST.** We need a dedicated `Spectral.AbstractCode` module to convert it to `sp_type()` records.

## Decisions

| Decision | Choice |
|---|---|
| Implementation approach | Write `Spectral.AbstractCode` Elixir module (Elixir AST → sp_type()) |
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

## Phase 1: Write `Spectral.AbstractCode` Elixir Module

**File:** `lib/spectral/abstract_code.ex`

Since Phase 0 confirmed the compile-time type bodies are **Elixir AST** (not Erlang abstract format), we implement the conversion natively in Elixir. No changes to spectra are needed.

### Module responsibilities

`Spectral.AbstractCode` converts compile-time Elixir type/spec attributes into `sp_type()` records using the Erlang record constructors already available via `Record.extract(..., from_lib: "spectra/include/spectra_internal.hrl")`.

### Key functions to implement

| Function | Purpose |
|---|---|
| `type_from_attribute/1` | Top-level: converts a `@type` attribute to `{name, arity, sp_type(), line}` |
| `spec_from_attributes/1` | Top-level: groups `@spec` attribute entries by name+arity, returns `[{name, arity, [sp_function_spec()]}]` |
| `convert_type_body/1` | Converts Elixir type AST body → `sp_type()` record |
| `convert_map_fields/1` | Converts `{:%{}, meta, fields}` entries → `[literal_map_field \| typed_map_field]` |

### Elixir AST → sp_type() conversion rules (from Phase 0)

```elixir
# Simple types: {:integer, meta, []} → sp_simple_type(type: :integer)
# Range: {:.., meta, [lo, hi]} → sp_range(lower_bound: lo, upper_bound: hi)
# Literal atom: :foo → sp_literal(value: :foo, binary_value: "foo")
# Literal nil/true/false: nil → sp_literal(value: nil, binary_value: "nil")
# Literal integer: 42 → sp_literal(value: 42, binary_value: "42")
# Union: {:|, meta, [A, {:|, meta, [B, C]}]} → sp_union(types: [A, B, C]) (flatten!)
# List shorthand: [elem_ast] → sp_list(type: convert(elem_ast))
# list(): {:list, meta, []} → sp_list(type: sp_simple_type(type: :term))
# Tuple: {:{}, meta, fields} → sp_tuple(fields: [convert(f) || f <- fields])
# tuple(): {:tuple, meta, []} → sp_tuple(fields: :any)
# Map: {:%{}, meta, fields} → sp_map(...) (see map field conversion)
# Struct: {:%, meta, [aliases, {:%{}, ...}]} → sp_map with __struct__ field
# Remote type: {{:., meta, [{:__aliases__,_,aliases}, :t]}, meta, args} → sp_remote_type(...)
# Remote type (lowercase): {:keyword, meta, args} → sp_remote_type(mfargs: {:elixir, :keyword, ...})
# User type ref: {:my_type, meta, args} → sp_user_type_ref(type_name: :my_type, ...)
# Type var: {:a, meta, nil} → sp_var(name: :a)
# Param type: {:t_param, meta, [var_ast]} (type args) → sp_type_with_variables(...)
# fun(): {:fun, meta, []} → sp_function(args: :any, return: sp_simple_type(type: :term))
# (A -> B): [{:->, meta, [[arg_ast], return_ast]}] → sp_function(args: [...], return: ...)
```

### Map field conversion rules

```elixir
# {key_ast, val_ast} with plain atom key → literal_map_field(kind: :exact, name: :key)
# {{:required, meta, [:key]}, val_ast} → literal_map_field(kind: :exact, name: :key)
# {{:optional, meta, [:key]}, val_ast} → literal_map_field(kind: :assoc, name: :key)
# {key_type_ast, val_type_ast} (non-literal key) → typed_map_field(kind: :exact, ...)
# __struct__ field detected → extract struct_name, remove from fields
```

### Spec conversion rules

```elixir
# Simple: {:"::", meta, [{fun_name, meta, arg_asts}, return_ast]}
# Bounded: {:when, meta, [{:"::", meta, [{fun_name, meta, arg_asts}, return_ast]}, when_clauses]}
# where when_clauses is a keyword list: [a: type_ast, b: type_ast]
# → substitute vars in arg_asts and return_ast, then convert
```

### No changes to spectra needed

The `spectra_type_info` and `spectra_type` Erlang modules are already fully exported and usable. The sp_type records are constructed via `Record.extract` as already done in `Spectral` and `Spectral.TypeInfo`.

## Phase 2: Modify Spectral's `__before_compile__`

**File:** `lib/spectral.ex`

### 2a. Convert type attributes to sp_type() at compile time

Instead of just extracting `{line, :type, {name, arity}}`, call `Spectral.AbstractCode.type_from_attribute/1`:

```elixir
converted_types =
  type_attrs
  |> Enum.map(&Spectral.AbstractCode.type_from_attribute/1)
  |> Enum.reject(&is_nil/1)
```

### 2b. Convert spec attributes at compile time

```elixir
converted_specs = Spectral.AbstractCode.spec_from_attributes(spec_attrs)
```

### 2c. Detect codec behaviour

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
