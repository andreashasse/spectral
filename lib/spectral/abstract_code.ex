defmodule Spectral.AbstractCode do
  @moduledoc false

  # Converts compile-time Elixir type AST (from @type / @typep module attributes)
  # into the Erlang sp_type() records that spectra expects.
  #
  # This is the compile-time equivalent of :spectra_abstract_code.field_info_to_type/1,
  # which operates on Erlang abstract format from BEAM debug info. Here we operate on
  # the raw Elixir-quoted AST that is available at compile time.
  #
  # The entry point is convert_module_types/2, which takes the accumulated @type/@typep
  # attributes and returns a type_info() record (as a quoted, escaped term).

  require Record

  Record.defrecord(
    :sp_simple_type,
    Record.extract(:sp_simple_type, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecord(
    :sp_tuple,
    Record.extract(:sp_tuple, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecord(
    :sp_map,
    Record.extract(:sp_map, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecord(
    :sp_union,
    Record.extract(:sp_union, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecord(
    :sp_literal,
    Record.extract(:sp_literal, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecord(
    :sp_rec_ref,
    Record.extract(:sp_rec_ref, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecord(
    :sp_remote_type,
    Record.extract(:sp_remote_type, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecord(
    :sp_user_type_ref,
    Record.extract(:sp_user_type_ref, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecord(
    :sp_var,
    Record.extract(:sp_var, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecord(
    :sp_range,
    Record.extract(:sp_range, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecord(
    :sp_list,
    Record.extract(:sp_list, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecord(
    :sp_nonempty_list,
    Record.extract(:sp_nonempty_list, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecord(
    :sp_maybe_improper_list,
    Record.extract(:sp_maybe_improper_list, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecord(
    :sp_nonempty_improper_list,
    Record.extract(:sp_nonempty_improper_list,
      from_lib: "spectra/include/spectra_internal.hrl"
    )
  )

  Record.defrecord(
    :sp_function,
    Record.extract(:sp_function, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecord(
    :sp_function_spec,
    Record.extract(:sp_function_spec, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecord(
    :sp_type_with_variables,
    Record.extract(:sp_type_with_variables, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecord(
    :sp_rec,
    Record.extract(:sp_rec, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecord(
    :sp_rec_field,
    Record.extract(:sp_rec_field, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecord(
    :literal_map_field,
    Record.extract(:literal_map_field, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecord(
    :typed_map_field,
    Record.extract(:typed_map_field, from_lib: "spectra/include/spectra_internal.hrl")
  )

  @primary_types ~w(string nonempty_string integer boolean atom float binary nonempty_binary
                    number term pid iodata iolist port reference bitstring nonempty_bitstring
                    none)a

  @predefined_int_range_types ~w(non_neg_integer neg_integer pos_integer)a

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc false
  @spec convert_type_ast(Macro.t(), module(), keyword()) :: :spectra.sp_type()
  def convert_type_ast(ast, current_module \\ nil, aliases \\ []) do
    alias_map = build_alias_map(aliases)
    resolved = resolve_ast_refs(ast, current_module, alias_map)
    do_convert(resolved)
  end

  @doc false
  @spec wrap_type_with_vars(:spectra.sp_type(), [atom()]) :: :spectra.sp_type()
  def wrap_type_with_vars(sp_type, vars) when is_list(vars) do
    sp_type_with_variables(type: sp_type, vars: vars)
  end

  @doc false
  @spec convert_spec_ast(Macro.t(), module(), keyword()) :: :spectra.sp_function_spec()
  def convert_spec_ast(spec_ast, current_module \\ nil, aliases \\ []) do
    alias_map = build_alias_map(aliases)
    resolved = resolve_ast_refs(spec_ast, current_module, alias_map)
    do_convert_spec(resolved)
  end

  # Build a map from short alias atom to full module atom.
  # env.aliases entries: {aliased_as_full_module, target_full_module}
  # __aliases__ AST uses short atom segments like :Address, not :"Elixir.Address"
  defp build_alias_map([]), do: %{}

  defp build_alias_map(aliases) do
    Map.new(aliases, fn {aliased_as, full_module} ->
      short_name =
        aliased_as
        |> Module.split()
        |> List.last()
        |> String.to_atom()

      {short_name, full_module}
    end)
  end

  # Pre-pass: replace __MODULE__ and resolve aliases in the type AST
  defp resolve_ast_refs(ast, current_module, alias_map) do
    do_resolve(ast, current_module, alias_map)
  end

  defp do_resolve({:__MODULE__, meta, nil}, mod, _alias_map) when is_atom(mod) do
    {:__aliases__, meta, [mod]}
  end

  # Resolve __aliases__ with a single short name using alias_map
  defp do_resolve({:__aliases__, meta, [short_name]}, _mod, alias_map)
       when is_atom(short_name) and map_size(alias_map) > 0 do
    case Map.fetch(alias_map, short_name) do
      {:ok, full_module} -> {:__aliases__, meta, [full_module]}
      :error -> {:__aliases__, meta, [short_name]}
    end
  end

  defp do_resolve({tag, meta, args}, mod, alias_map) when is_list(args) do
    {do_resolve(tag, mod, alias_map), meta, Enum.map(args, &do_resolve(&1, mod, alias_map))}
  end

  defp do_resolve({tag, meta, args}, _mod, _alias_map) when not is_list(args) do
    {tag, meta, args}
  end

  defp do_resolve(list, mod, alias_map) when is_list(list) do
    Enum.map(list, &do_resolve(&1, mod, alias_map))
  end

  defp do_resolve({k, v}, mod, alias_map) do
    {do_resolve(k, mod, alias_map), do_resolve(v, mod, alias_map)}
  end

  defp do_resolve(other, _mod, _alias_map), do: other

  # ---------------------------------------------------------------------------
  # Type AST → sp_type()
  # ---------------------------------------------------------------------------

  # Annotated type  (var :: type)
  defp do_convert({:"::", _meta, [{_var, _, nil}, type_ast]}) do
    do_convert(type_ast)
  end

  # Literal nil value  (bare nil in a union, e.g. MyStruct | nil)
  defp do_convert(nil) do
    sp_literal(value: nil, binary_value: "nil")
  end

  # Literal boolean values
  defp do_convert(true) do
    sp_literal(value: true, binary_value: "true")
  end

  defp do_convert(false) do
    sp_literal(value: false, binary_value: "false")
  end

  # Literal atom (e.g. :ok, :error, :hello)
  defp do_convert(value) when is_atom(value) do
    sp_literal(value: value, binary_value: Atom.to_string(value))
  end

  # Literal integer
  defp do_convert(value) when is_integer(value) do
    sp_literal(value: value, binary_value: Integer.to_string(value))
  end

  # Type variable  (e.g. `a` in `@type t(a) :: a`)
  defp do_convert({name, _meta, nil}) when is_atom(name) do
    sp_var(name: name)
  end

  # Union  {:|, meta, [left, right]}  — right-nested in AST, must flatten
  defp do_convert({:|, _meta, [left, right]}) do
    left_type = do_convert(left)
    right_types = flatten_union(right)
    sp_union(types: [left_type | right_types])
  end

  # Range  {:.., meta, [lower, upper]}
  defp do_convert({:.., _meta, [lower, upper]}) do
    sp_range(type: :integer, lower_bound: integer_value(lower), upper_bound: integer_value(upper))
  end

  # Unary negation on integer literal (e.g. -1 in ranges)
  defp do_convert({:-, _meta, [operand]}) when is_integer(operand) do
    sp_literal(value: -operand, binary_value: Integer.to_string(-operand))
  end

  # Function type with arrow  (arg1, arg2 -> return)
  # AST: [{:->, meta, [[arg_asts...], return_ast]}]
  defp do_convert([{:->, _meta, [arg_asts, return_ast]}]) when is_list(arg_asts) do
    args = Enum.map(arg_asts, &do_convert/1)
    return = do_convert(return_ast)
    sp_function(args: args, return: return)
  end

  # Shorthand list type  [elem_type]  — means list(elem_type), i.e. possibly empty
  defp do_convert([elem_ast]) do
    sp_list(type: do_convert(elem_ast))
  end

  # Empty list literal  []  → nil literal (same as Erlang nil)
  defp do_convert([]) do
    sp_literal(value: [], binary_value: "[]")
  end

  # Remote type  Module.type()  — {{:., meta, [aliases, :type]}, meta, args}
  defp do_convert({{:., _dmeta, [{:__aliases__, _ameta, aliases}, type_name]}, _meta, args})
       when is_atom(type_name) and is_list(args) do
    module = Module.concat(aliases)
    converted_args = Enum.map(args, &do_convert/1)
    sp_remote_type(mfargs: {module, type_name, converted_args}, arity: length(converted_args))
  end

  # Struct  %MyStruct{field: type, ...}
  # AST: {:%, meta, [{:__aliases__, _, [...]}, {:%{}, meta, fields}]}
  defp do_convert({:%, _meta, [{:__aliases__, _, aliases}, {:%{}, _mmeta, kv_pairs}]}) do
    struct_module = Module.concat(aliases)

    field_entries =
      kv_pairs
      |> Enum.map(fn {key, val_ast} when is_atom(key) ->
        literal_map_field(
          kind: :exact,
          name: key,
          binary_name: Atom.to_string(key),
          val_type: do_convert(val_ast)
        )
      end)
      |> Enum.sort_by(fn f -> literal_map_field(f, :name) end)

    sp_map(fields: field_entries, struct_name: struct_module)
  end

  # Map  %{...}  — {:%{}, meta, fields}
  defp do_convert({:%{}, _meta, fields}) when is_list(fields) do
    map_fields = Enum.flat_map(fields, &convert_map_field/1)
    {struct_name, final_fields} = extract_struct_name(map_fields)
    # Non-struct maps use :undefined (matching Erlang spectra convention)
    sp_map(fields: final_fields, struct_name: struct_name || :undefined)
  end

  # Tuple  {A, B}  — 2-element tuple shorthand
  defp do_convert({:{}, _meta, field_asts}) do
    sp_tuple(fields: Enum.map(field_asts, &do_convert/1))
  end

  defp do_convert({a, b}) do
    sp_tuple(fields: [do_convert(a), do_convert(b)])
  end

  # Named types with no module qualifier — could be built-in or user-defined
  defp do_convert({name, _meta, args}) when is_atom(name) and is_list(args) do
    convert_named_type(name, args)
  end

  # Catch-all
  defp do_convert(other) do
    raise ArgumentError,
          "Spectral.AbstractCode: unsupported type AST: #{inspect(other, pretty: true)}"
  end

  # ---------------------------------------------------------------------------
  # Named types dispatch (built-ins vs user-defined)
  # ---------------------------------------------------------------------------

  defp convert_named_type(:any, []), do: sp_simple_type(type: :term)
  defp convert_named_type(:term, []), do: sp_simple_type(type: :term)
  defp convert_named_type(:dynamic, []), do: sp_simple_type(type: :term)
  defp convert_named_type(:none, []), do: sp_simple_type(type: :none)
  defp convert_named_type(:no_return, []), do: sp_simple_type(type: :none)
  defp convert_named_type(:node, []), do: sp_simple_type(type: :atom)
  defp convert_named_type(:module, []), do: sp_simple_type(type: :atom)
  defp convert_named_type(:pid, []), do: sp_simple_type(type: :pid)
  defp convert_named_type(:port, []), do: sp_simple_type(type: :port)
  defp convert_named_type(:reference, []), do: sp_simple_type(type: :reference)
  defp convert_named_type(:iodata, []), do: sp_simple_type(type: :iodata)
  defp convert_named_type(:iolist, []), do: sp_simple_type(type: :iolist)

  defp convert_named_type(t, []) when t in @primary_types, do: sp_simple_type(type: t)

  defp convert_named_type(t, []) when t in @predefined_int_range_types,
    do: sp_simple_type(type: t)

  defp convert_named_type(:arity, []) do
    sp_range(type: :integer, lower_bound: 0, upper_bound: 255)
  end

  defp convert_named_type(:byte, []) do
    sp_range(type: :integer, lower_bound: 0, upper_bound: 255)
  end

  defp convert_named_type(:char, []) do
    sp_range(type: :integer, lower_bound: 0, upper_bound: 0x10FFFF)
  end

  defp convert_named_type(:mfa, []) do
    sp_tuple(
      fields: [
        sp_simple_type(type: :atom),
        sp_simple_type(type: :atom),
        sp_range(type: :integer, lower_bound: 0, upper_bound: 255)
      ]
    )
  end

  defp convert_named_type(:timeout, []) do
    sp_union(
      types: [
        sp_simple_type(type: :non_neg_integer),
        sp_literal(value: :infinity, binary_value: "infinity")
      ]
    )
  end

  defp convert_named_type(:identifier, []) do
    sp_union(
      types: [
        sp_simple_type(type: :pid),
        sp_simple_type(type: :port),
        sp_simple_type(type: :reference)
      ]
    )
  end

  defp convert_named_type(:tuple, []) do
    sp_tuple(fields: :any)
  end

  defp convert_named_type(:map, []) do
    sp_map(
      fields: [
        typed_map_field(
          kind: :assoc,
          key_type: sp_simple_type(type: :term),
          val_type: sp_simple_type(type: :term)
        )
      ],
      struct_name: :undefined
    )
  end

  defp convert_named_type(:list, []) do
    sp_list(type: sp_simple_type(type: :term))
  end

  defp convert_named_type(:list, [elem_ast]) do
    sp_list(type: do_convert(elem_ast))
  end

  defp convert_named_type(:nonempty_list, []) do
    sp_nonempty_list(type: sp_simple_type(type: :term))
  end

  defp convert_named_type(:nonempty_list, [elem_ast]) do
    sp_nonempty_list(type: do_convert(elem_ast))
  end

  defp convert_named_type(:maybe_improper_list, []) do
    sp_maybe_improper_list(
      elements: sp_simple_type(type: :term),
      tail: sp_simple_type(type: :term)
    )
  end

  defp convert_named_type(:maybe_improper_list, [elem_ast, tail_ast]) do
    sp_maybe_improper_list(elements: do_convert(elem_ast), tail: do_convert(tail_ast))
  end

  defp convert_named_type(:nonempty_improper_list, [elem_ast, tail_ast]) do
    sp_nonempty_improper_list(elements: do_convert(elem_ast), tail: do_convert(tail_ast))
  end

  # fun()  →  sp_function(args: any, return: term)
  defp convert_named_type(:fun, []) do
    sp_function(args: :any, return: sp_simple_type(type: :term))
  end

  # function() — same as fun()
  defp convert_named_type(:function, []) do
    sp_function(args: :any, return: sp_simple_type(type: :term))
  end

  # (... -> return)  AST from fun with args
  # In Elixir, (type1, type2 -> return) becomes {:fun, meta, [{:->, meta, [[args...], return]}]}
  # but quoted as a list-with-arrow literal: [{:->, meta, [[arg1, arg2], return]}]
  # We handle this through the list path - see do_convert for [elem] and [] patterns.
  # For fun/function with args, they appear as: {:fun, meta, [{:->, meta, [args, ret]}]}
  # where args is a list.

  # Elixir bare lowercase types that are remote Elixir types: keyword, keyword(t), etc.
  defp convert_named_type(:keyword, []) do
    sp_remote_type(mfargs: {:elixir, :keyword, []}, arity: 0)
  end

  defp convert_named_type(:keyword, [type_ast]) do
    sp_remote_type(mfargs: {:elixir, :keyword, [do_convert(type_ast)]}, arity: 1)
  end

  # User-defined type reference (local)
  defp convert_named_type(name, args) when is_atom(name) do
    converted_args = Enum.map(args, &do_convert/1)
    sp_user_type_ref(type_name: name, variables: converted_args, arity: length(converted_args))
  end

  # ---------------------------------------------------------------------------
  # Spec conversion
  # ---------------------------------------------------------------------------

  # Simple spec: (arg1, arg2 -> return)
  defp do_convert_spec({:"::", _meta, [{_name, _nmeta, arg_asts}, return_ast]}) do
    args = if is_list(arg_asts), do: Enum.map(arg_asts, &do_convert/1), else: []
    return = do_convert(return_ast)
    sp_function_spec(args: args, return: return)
  end

  # Bounded spec: (when [var: type, ...])
  defp do_convert_spec({:when, _meta, [{:"::", _imeta, [head, return_ast]}, constraints]}) do
    # Store raw ASTs in constraint_map so substitute_vars returns ASTs (not sp_types)
    constraint_map =
      constraints
      |> Enum.map(fn {var_name, type_ast} -> {var_name, type_ast} end)
      |> Map.new()

    # substitute vars in head and return
    {_name, _nmeta, arg_asts} = head

    args =
      if is_list(arg_asts),
        do: Enum.map(arg_asts, fn a -> substitute_vars(a, constraint_map) end),
        else: []

    return = substitute_vars(return_ast, constraint_map)

    sp_function_spec(
      args: Enum.map(args, &do_convert/1),
      return: do_convert(return)
    )
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp flatten_union({:|, _meta, [left, right]}) do
    [do_convert(left) | flatten_union(right)]
  end

  defp flatten_union(other) do
    [do_convert(other)]
  end

  defp integer_value(v) when is_integer(v), do: v
  defp integer_value({:-, _meta, [v]}) when is_integer(v), do: -v
  defp integer_value({:+, _meta, [v]}) when is_integer(v), do: v

  # Map field conversion — handles required/optional syntax in Elixir AST
  # required(key) => value  :  {{:required, _, [key_ast]}, val_ast}
  # optional(key) => value  :  {{:optional, _, [key_ast]}, val_ast}
  # plain key => value      :  {key_atom, val_ast}

  defp convert_map_field({{:required, _meta, [key_ast]}, val_ast}) do
    case key_ast do
      key when is_atom(key) ->
        [
          literal_map_field(
            kind: :exact,
            name: key,
            binary_name: Atom.to_string(key),
            val_type: do_convert(val_ast)
          )
        ]

      _ ->
        [
          typed_map_field(
            kind: :exact,
            key_type: do_convert(key_ast),
            val_type: do_convert(val_ast)
          )
        ]
    end
  end

  defp convert_map_field({{:optional, _meta, [key_ast]}, val_ast}) do
    case key_ast do
      key when is_atom(key) ->
        [
          literal_map_field(
            kind: :assoc,
            name: key,
            binary_name: Atom.to_string(key),
            val_type: do_convert(val_ast)
          )
        ]

      _ ->
        [
          typed_map_field(
            kind: :assoc,
            key_type: do_convert(key_ast),
            val_type: do_convert(val_ast)
          )
        ]
    end
  end

  defp convert_map_field({key, val_ast}) when is_atom(key) do
    [
      literal_map_field(
        kind: :exact,
        name: key,
        binary_name: Atom.to_string(key),
        val_type: do_convert(val_ast)
      )
    ]
  end

  # Plain key_type => val_type (no required/optional wrapper) is exact in Erlang abstract format
  defp convert_map_field({key_ast, val_ast}) do
    [typed_map_field(kind: :exact, key_type: do_convert(key_ast), val_type: do_convert(val_ast))]
  end

  defp extract_struct_name(map_fields) do
    {struct_fields, other_fields} =
      Enum.split_with(map_fields, fn
        literal_map_field(name: :__struct__) -> true
        _ -> false
      end)

    case struct_fields do
      [literal_map_field(val_type: sp_literal(value: struct_name))] when is_atom(struct_name) ->
        {struct_name, other_fields}

      _ ->
        {nil, map_fields}
    end
  end

  # Substitute type variable references in AST before converting
  defp substitute_vars({name, meta, nil}, constraint_map) when is_atom(name) do
    case Map.fetch(constraint_map, name) do
      {:ok, replacement} -> replacement
      :error -> {name, meta, nil}
    end
  end

  defp substitute_vars(other, _constraint_map), do: other
end
