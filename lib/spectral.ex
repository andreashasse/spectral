defmodule Spectral do
  require Record

  Record.defrecord(
    :sp_function_spec,
    Record.extract(:sp_function_spec, from_lib: "spectra/include/spectra_internal.hrl")
  )

  @moduledoc """
  Elixir wrapper for the Erlang `spectra` library.

  Provides idiomatic Elixir interfaces for encoding, decoding, and schema generation
  based on type specifications.

  ## API

  All functions are designed to work well with Elixir's pipe and with operators:

      %Person{name: "Alice", age: 30}
      |> Spectral.encode!(Person, :t)
      |> send_response()

      with {:ok, json} <- Spectral.encode(%Person{name: "Alice"}, Person, :t) do
        send_response(json)
      end

  """

  @typedoc "Spectra type information for a module. Alias for `:spectra.type_info()`."
  @type type_info :: :spectra.type_info()

  @typedoc "A reference to a named type `{:type, name, arity}` or record `{:record, name}`."
  @type sp_type_reference :: {:type, atom(), non_neg_integer()} | {:record, atom()}

  @typedoc "A spectra type structure or type reference. `sp_type()` is an opaque Erlang record."
  @type sp_type_or_ref :: :spectra.sp_type_or_ref()

  @typedoc """
  Options for `encode/5` and `encode!/5`.

  - `:pre_encoded` - Skip the final JSON serialization step and return the intermediate
    JSON term (a map/list) instead of iodata. Equivalent to `{:pre_encoded, true}`.
  - `{:pre_encoded, boolean()}` - Explicit boolean form; `false` gives the default behaviour.
  """
  @type encode_option :: :pre_encoded | {:pre_encoded, boolean()}

  @typedoc """
  Options for `decode/5` and `decode!/5`.

  - `:pre_decoded` - Accept an already-decoded JSON term as input, skipping the JSON
    parsing step. Equivalent to `{:pre_decoded, true}`.
  - `{:pre_decoded, boolean()}` - Explicit boolean form; `false` gives the default behaviour.
  """
  @type decode_option :: :pre_decoded | {:pre_decoded, boolean()}

  @typedoc """
  Options for `schema/4`.

  - `:pre_encoded` - Skip the final JSON serialization step and return a map instead of
    iodata. Equivalent to `{:pre_encoded, true}`.
  - `{:pre_encoded, boolean()}` - Explicit boolean form; `false` gives the default behaviour.
  """
  @type schema_option :: :pre_encoded | {:pre_encoded, boolean()}

  @doc """
  Adds documentation metadata for a type.

  Use this macro immediately before a `@type` definition to document it.
  The line number is automatically captured to pair the documentation
  with the correct type.

  ## Example

      defmodule Person do
        use Spectral

        spectral title: "Person", description: "A person record"
        @type t :: %Person{name: String.t()}
      end

  ## Fields — before a `@type`

  - `title` - A short title for the type
  - `description` - A detailed description
  - `deprecated` - Whether the type is deprecated (boolean)
  - `examples` - Example values (list)
  - `examples_function` - `{module, function_name, args}` tuple; called at schema
    generation time to produce examples. The function must be exported.
  - `type_parameters` - Static configuration forwarded as the `params` argument
    to `Spectral.Codec` callbacks for this type (any term)
  - `only` - List of field name atoms to include when encoding, decoding, and generating
    schemas. Fields not in the list are silently dropped. For Elixir structs, excluded
    fields are filled from the struct's defaults on decode.

  ## Fields — before a `@spec`

  - `summary` - Short one-line summary of the function / endpoint
  - `description` - A detailed description
  - `deprecated` - Whether the function is deprecated (boolean)
  """
  defmacro spectral(metadata) when is_list(metadata) do
    line = __CALLER__.line

    quote do
      @spectral {unquote(line), Map.new(unquote(metadata))}
    end
  end

  defmacro spectral({:%{}, _meta, fields}) when is_list(fields) do
    line = __CALLER__.line

    quote do
      @spectral {unquote(line), Map.new(unquote(fields))}
    end
  end

  defmacro spectral(metadata) do
    raise ArgumentError, """
    spectral macro requires a keyword list or map, got: #{inspect(metadata)}

    Valid usage:
      spectral title: "My Type", description: "A description"
      spectral %{title: "My Type", description: "A description"}
    """
  end

  @doc """
  Sets up the Spectral macros and injects `__spectra_type_info__/0`.

  When you `use Spectral`, the `spectral/1` macro is imported and a
  `__spectra_type_info__/0` function is injected that Spectral's encode, decode,
  and schema functions use internally.

  ## Annotating Types

  Place `spectral/1` immediately before a `@type` to attach documentation
  to generated JSON schemas and OpenAPI component schemas:

      defmodule Person do
        use Spectral

        defstruct [:name, :age]

        spectral title: "Person", description: "A person record"
        @type t :: %Person{name: String.t(), age: non_neg_integer()}
      end

  Types without a `spectral` call will not have title/description in their schemas.
  See `spectral/1` for the full list of supported annotation fields.

  ## Annotating Functions (Endpoint Documentation)

  Place `spectral/1` immediately before a `@spec` to attach endpoint metadata,
  which `Spectral.OpenAPI.endpoint/5` reads automatically:

      defmodule MyController do
        use Spectral

        spectral summary: "Get user", description: "Returns a user by ID"
        @spec show(map(), map()) :: map()
        def show(_conn, _params), do: %{}
      end

      endpoint = Spectral.OpenAPI.endpoint(:get, "/users/{id}", MyController, :show, 2)
  """
  defmacro __using__(_opts) do
    quote do
      Module.register_attribute(__MODULE__, :spectral, accumulate: true)
      import Spectral, only: [spectral: 1]
      @before_compile Spectral
    end
  end

  @doc false
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
  # credo:disable-for-this-file Credo.Check.Refactor.Nesting
  defmacro __before_compile__(env) do
    spectral_attrs = Module.get_attribute(env.module, :spectral) || []

    # @type and @typep are separate attributes; combine so spectral/1 can annotate private types
    type_attrs =
      (Module.get_attribute(env.module, :type) || []) ++
        (Module.get_attribute(env.module, :typep) || [])

    spec_attrs = Module.get_attribute(env.module, :spec) || []
    behaviours = Module.get_attribute(env.module, :behaviour) || []
    implements_codec = :spectra_codec in behaviours or Spectral.Codec in behaviours

    types_with_lines = parse_type_attrs(type_attrs, env)
    specs_with_lines = parse_spec_attrs(spec_attrs)

    {type_doc_map, function_doc_map} =
      pair_spectral_docs(spectral_attrs, types_with_lines, specs_with_lines, env)

    type_info =
      :spectra_type_info.new(env.module, implements_codec)
      |> add_types(types_with_lines, type_doc_map, env)
      |> add_functions(specs_with_lines, function_doc_map, env)

    escaped_type_info = Macro.escape(type_info)

    quote do
      @doc false
      def __spectra_type_info__ do
        unquote(escaped_type_info)
      end
    end
  end

  defp parse_type_attrs(type_attrs, _env) do
    Enum.map(type_attrs, fn {kind, {:"::", meta, [{name, _, args_or_nil}, type_expr]}, _}
                            when kind in [:type, :typep] and is_atom(name) ->
      arity = if is_list(args_or_nil), do: length(args_or_nil), else: 0
      line = Keyword.get(meta, :line, 0)
      vars = if is_list(args_or_nil), do: Enum.map(args_or_nil, fn {v, _, _} -> v end), else: []
      {line, :type, {name, arity, vars, type_expr}}
    end)
  end

  defp parse_spec_attrs(spec_attrs) do
    Enum.flat_map(spec_attrs, fn spec_ast ->
      case spec_ast do
        {:spec, {:"::", meta, [{name, _, args_or_nil}, _return_type]} = inner, _env}
        when is_atom(name) ->
          arity = if is_list(args_or_nil), do: length(args_or_nil), else: 0
          line = Keyword.get(meta, :line, 0)
          [{line, :function, {name, arity, inner}}]

        {:spec, {:when, _, [{:"::", meta, [{name, _, args_or_nil}, _return_type]}, _]} = inner,
         _env}
        when is_atom(name) ->
          arity = if is_list(args_or_nil), do: length(args_or_nil), else: 0
          line = Keyword.get(meta, :line, 0)
          [{line, :function, {name, arity, inner}}]
      end
    end)
  end

  # Pairs each spectral annotation with the next @type or @spec that follows it by line.
  # Returns {type_doc_map, function_doc_map} keyed by {name, arity}.
  defp pair_spectral_docs(spectral_attrs, types_with_lines, specs_with_lines, env) do
    all_items =
      (Enum.map(spectral_attrs, fn {line, doc} -> {line, :spectral, doc} end) ++
         types_with_lines ++
         specs_with_lines)
      |> Enum.sort_by(fn {line, _, _} -> line end)

    {pairs_reversed, leftover} =
      Enum.reduce(all_items, {[], nil}, fn
        {line, :spectral, doc}, {pairs, _pending} -> {pairs, {line, doc}}
        # No pending annotation — skip; add_types/add_functions will still process this item without doc
        {_line, _kind, _ref}, {pairs, nil} -> {pairs, nil}
        {_line, kind, ref}, {pairs, {_spectral_line, doc}} -> {[{kind, ref, doc} | pairs], nil}
      end)

    if leftover != nil do
      {spectral_line, _doc} = leftover

      raise ArgumentError,
            "spectral call on line #{spectral_line} in #{inspect(env.module)} has no corresponding @type or @spec definition after it"
    end

    paired_docs = Enum.reverse(pairs_reversed)

    type_doc_map =
      Map.new(for {:type, {name, arity, _, _}, doc} <- paired_docs, do: {{name, arity}, doc})

    function_doc_map =
      Map.new(for {:function, {name, arity, _}, doc} <- paired_docs, do: {{name, arity}, doc})

    {type_doc_map, function_doc_map}
  end

  defp add_types(type_info, types_with_lines, type_doc_map, env) do
    Enum.reduce(types_with_lines, type_info, fn {_line, :type, {name, arity, vars, type_expr}},
                                                acc ->
      sp_type = Spectral.AbstractCode.convert_type_ast(type_expr, env.module, env.aliases)

      sp_type_with_vars =
        case vars do
          [] -> sp_type
          var_list -> Spectral.AbstractCode.wrap_type_with_vars(sp_type, var_list)
        end

      tagged = :spectra_type.update_meta(sp_type_with_vars, %{name: {:type, name, arity}})

      :spectra_type_info.add_type(
        acc,
        name,
        arity,
        apply_type_doc(tagged, type_doc_map, name, arity)
      )
    end)
  end

  defp apply_type_doc(tagged, type_doc_map, name, arity) do
    case Map.fetch(type_doc_map, {name, arity}) do
      {:ok, doc} ->
        {type_params, doc1} = Map.pop(doc, :type_parameters)
        {only, doc_clean} = Map.pop(doc1, :only)

        tagged
        |> then(fn t ->
          if only != nil,
            do: :spectra_abstract_code.apply_only(t, validate_only(only)),
            else: t
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

      :error ->
        tagged
    end
  end

  # spec_attrs are ordered last-to-first per clause, so prepend each new clause to reconstruct
  # source order, then convert and attach docs.
  defp add_functions(type_info, specs_with_lines, function_doc_map, env) do
    grouped_specs =
      Enum.reduce(specs_with_lines, %{}, fn {_line, :function, {name, arity, inner_ast}}, acc ->
        Map.update(acc, {name, arity}, [inner_ast], fn existing -> [inner_ast | existing] end)
      end)

    Enum.reduce(grouped_specs, type_info, fn {{name, arity}, spec_asts}, acc ->
      func_specs =
        Enum.map(spec_asts, fn inner_ast ->
          Spectral.AbstractCode.convert_spec_ast(inner_ast, env.module, env.aliases)
        end)

      final_func_specs =
        case Map.fetch(function_doc_map, {name, arity}) do
          {:ok, raw_doc} ->
            normalized_doc = :spectra_type.normalize_function_doc(raw_doc)
            Enum.map(func_specs, fn spec -> __set_function_spec_doc__(spec, normalized_doc) end)

          :error ->
            func_specs
        end

      :spectra_type_info.add_function(acc, name, arity, final_func_specs)
    end)
  end

  @doc false
  defp validate_only(only) when is_list(only) do
    case Enum.all?(only, &is_atom/1) do
      true ->
        only

      false ->
        raise ArgumentError, "spectral :only must be a list of atoms, got: #{inspect(only)}"
    end
  end

  defp validate_only(only) do
    raise ArgumentError, "spectral :only must be a list of atoms, got: #{inspect(only)}"
  end

  @doc false
  def __attach_function_doc__(type_info, name, arity, raw_doc) do
    normalized_doc = :spectra_type.normalize_function_doc(raw_doc)

    case :spectra_type_info.find_function(type_info, name, arity) do
      {:ok, func_specs} ->
        updated_specs =
          Enum.map(func_specs, fn spec ->
            __set_function_spec_doc__(spec, normalized_doc)
          end)

        :spectra_type_info.add_function(type_info, name, arity, updated_specs)

      :error ->
        type_info
    end
  end

  @doc false
  def __set_function_spec_doc__(spec, normalized_doc) do
    meta = sp_function_spec(spec, :meta)
    sp_function_spec(spec, meta: Map.put(meta, :doc, normalized_doc))
  end

  @doc """
  Encodes data to the specified format.

  ## Parameters

  - `data` - The data to encode
  - `module` - Module containing the type definition
  - `type_ref` - Type reference (typically an atom like `:t`)
  - `format` - Format to encode to (default: `:json`)
  - `opts` - Options list (default: `[]`). Supported options:
    - `:pre_encoded` - Return the intermediate JSON term (map/list) instead of iodata.

  ## Returns

  - `{:ok, iodata()}` - Encoded data on success (default)
  - `{:ok, dynamic()}` - Encoded data as a JSON term when `:pre_encoded` option is set
  - `{:error, [%Spectral.Error{}]}` - List of errors on failure

  ## Examples

      iex> person = %Person{name: "Alice", age: 30, address: %Person.Address{street: "Ystader Straße", city: "Berlin"}}
      ...> with {:ok, json} <- Spectral.encode(person, Person, :t) do
      ...>  IO.iodata_to_binary(json)
      ...> end
      ~s({"address":{"city":"Berlin","street":"Ystader Straße"},"age":30,"name":"Alice"})

      iex> {:ok, json} = %Person{name: "Alice"} |> Spectral.encode(Person, :t)
      iex> IO.iodata_to_binary(json)
      ~s({"name":"Alice"})

      iex> {:ok, term} = %Person{name: "Alice", age: 30} |> Spectral.encode(Person, :t, :json, [:pre_encoded])
      iex> term["name"]
      "Alice"
  """
  @spec encode(dynamic(), module() | type_info(), atom() | sp_type_or_ref(), atom(), [
          encode_option()
        ]) ::
          {:ok, iodata() | dynamic()} | {:error, [Spectral.Error.t()]}
  def encode(data, module, type_ref, format \\ :json, opts \\ []) do
    :spectra.encode(format, module, type_ref, data, opts)
    |> convert_result()
  rescue
    error in ErlangError ->
      handle_erlang_error(error, :encode, module, type_ref)
  end

  @doc """
  Decodes data from the specified format.

  ## Parameters

  - `data` - The data to decode (binary for JSON, string for string format; or a JSON term when `:pre_decoded` option is set)
  - `module` - Module containing the type definition
  - `type_ref` - Type reference (typically an atom like `:t`)
  - `format` - Format to decode from (default: `:json`)
  - `opts` - Options list (default: `[]`). Supported options:
    - `:pre_decoded` - Accept an already-decoded JSON term as input, skipping JSON parsing.

  ## Returns

  - `{:ok, dynamic()}` - Decoded data on success
  - `{:error, [%Spectral.Error{}]}` - List of errors on failure

  ## Examples

      iex> ~s({"name":"Alice","age":30,"address":{"street":"Ystader Straße", "city": "Berlin"}})
      ...> |> Spectral.decode(Person, :t)
      {:ok, %Person{age: 30, name: "Alice", address: %Person.Address{street: "Ystader Straße", city: "Berlin"}}}

      iex> ~s({"name":"Alice"})
      ...> |> Spectral.decode(Person, :t)
      {:ok, %Person{age: nil, name: "Alice", address: nil}}

      iex> ~s({"name":"Alice","age":30,"extra_field":"ignored"})
      ...> |> Spectral.decode(Person, :t)
      {:ok, %Person{age: 30, name: "Alice", address: nil}}

      iex> Spectral.decode(%{"name" => "Alice", "age" => 30}, Person, :t, :json, [:pre_decoded])
      {:ok, %Person{age: 30, name: "Alice", address: nil}}
  """
  @spec decode(dynamic(), module() | type_info(), atom() | sp_type_or_ref(), atom(), [
          decode_option()
        ]) ::
          {:ok, dynamic()} | {:error, [Spectral.Error.t()]}
  def decode(data, module, type_ref, format \\ :json, opts \\ []) do
    :spectra.decode(format, module, type_ref, data, opts)
    |> convert_result()
  rescue
    error in ErlangError ->
      handle_erlang_error(error, :decode, module, type_ref)
  end

  @doc """
  Generates a schema for the specified type.

  ## Parameters

  - `module` - Module containing the type definition
  - `type_ref` - Type reference (typically an atom like `:t`)
  - `format` - Schema format (default: `:json_schema`)

  ## Returns

  - `iodata()` - Generated schema

  ## Examples

      iex> schemadata = Spectral.schema(Person, :t)
      iex> is_binary(IO.iodata_to_binary(schemadata))
      true
  """
  @spec schema(module() | type_info(), atom() | sp_type_or_ref(), atom()) :: iodata()
  def schema(module, type_ref, format \\ :json_schema) do
    :spectra.schema(format, module, type_ref)
  rescue
    error in ErlangError ->
      handle_erlang_error(error, :schema, module, type_ref)
  end

  @doc """
  Generates a schema for the specified type, with options.

  Like `schema/3` but accepts an options list.

  ## Parameters

  - `module` - Module containing the type definition
  - `type_ref` - Type reference (typically an atom like `:t`)
  - `format` - Schema format (default: `:json_schema`)
  - `opts` - Options list. Supported options:
    - `:pre_encoded` - Return a map instead of iodata, skipping JSON encoding.

  ## Returns

  - `iodata()` - Generated schema (default)
  - `dynamic()` - Schema as a map when `:pre_encoded` option is set

  ## Examples

      iex> schema = Spectral.schema(Person, :t, :json_schema, [:pre_encoded])
      iex> is_map(schema)
      true
  """
  @spec schema(module() | type_info(), atom() | sp_type_or_ref(), atom(), [schema_option()]) ::
          iodata() | dynamic()
  def schema(module, type_ref, format, opts) when is_list(opts) do
    :spectra.schema(format, module, type_ref, opts)
  rescue
    error in ErlangError ->
      handle_erlang_error(error, :schema, module, type_ref)
  end

  @doc """
  Encodes data to the specified format, raising on error.

  Like `encode/5` but raises `Spectral.Error` instead of returning an error tuple.

  ## Parameters

  - `data` - The data to encode
  - `module` - Module containing the type definition
  - `type_ref` - Type reference (typically an atom like `:t`)
  - `format` - Format to encode to (default: `:json`)
  - `opts` - Options list (default: `[]`). Supported options:
    - `:pre_encoded` - Return the intermediate JSON term (map/list) instead of iodata.

  ## Returns

  - `iodata()` - Encoded data on success (default)
  - `dynamic()` - Encoded data as a JSON term when `:pre_encoded` option is set

  ## Raises

  - `Spectral.Error` - If encoding fails

  ## Examples

      iex> %Person{name: "Alice", age: 30}
      ...> |> Spectral.encode!(Person, :t)
      ...> |> IO.iodata_to_binary()
      ~s({"age":30,"name":"Alice"})
  """
  @spec encode!(dynamic(), module() | type_info(), atom() | sp_type_or_ref(), atom(), [
          encode_option()
        ]) :: iodata() | dynamic()
  def encode!(data, module, type_ref, format \\ :json, opts \\ []) do
    case encode(data, module, type_ref, format, opts) do
      {:ok, result} ->
        result

      {:error, [error | _]} ->
        raise Spectral.Error.exception(error)
    end
  end

  @doc """
  Decodes data from the specified format, raising on error.

  Like `decode/5` but raises `Spectral.Error` instead of returning an error tuple.

  ## Parameters

  - `data` - The data to decode (binary for JSON, string for string format; or a JSON term when `:pre_decoded` option is set)
  - `module` - Module containing the type definition
  - `type_ref` - Type reference (typically an atom like `:t`)
  - `format` - Format to decode from (default: `:json`)
  - `opts` - Options list (default: `[]`). Supported options:
    - `:pre_decoded` - Accept an already-decoded JSON term as input, skipping JSON parsing.

  ## Returns

  - `dynamic()` - Decoded data on success

  ## Raises

  - `Spectral.Error` - If decoding fails

  ## Examples

      iex> ~s({"name":"Alice","age":30})
      ...> |> Spectral.decode!(Person, :t)
      %Person{age: 30, name: "Alice", address: nil}
  """
  @spec decode!(dynamic(), module() | type_info(), atom() | sp_type_or_ref(), atom(), [
          decode_option()
        ]) ::
          dynamic()
  def decode!(data, module, type_ref, format \\ :json, opts \\ []) do
    case decode(data, module, type_ref, format, opts) do
      {:ok, result} ->
        result

      {:error, [error | _]} ->
        raise Spectral.Error.exception(error)
    end
  end

  # Private helper to convert Erlang results to Elixir
  defp convert_result({:ok, result}), do: {:ok, result}

  defp convert_result({:error, erlang_errors}) when is_list(erlang_errors) do
    {:error, Spectral.Error.from_erlang_list(erlang_errors)}
  end

  defp handle_erlang_error(%ErlangError{original: original} = error, operation, module, type_ref) do
    case original do
      {:module_types_not_found, ^module, _reason} ->
        raise ArgumentError,
              "module #{inspect(module)} not found, not loaded, or not compiled with debug_info (#{operation})"

      {:type_or_record_not_found, ^type_ref} ->
        raise ArgumentError,
              "type #{inspect(type_ref)} not found in module #{inspect(module)} (#{operation})"

      {:type_not_found, type_name, _arity} when type_name == type_ref ->
        raise ArgumentError,
              "type #{inspect(type_ref)} not found in module #{inspect(module)} (#{operation})"

      {:type_not_supported, type_info} ->
        raise ArgumentError,
              "type not supported: #{inspect(type_info)} (#{operation})"

      _other ->
        # Re-raise the original ErlangError if it's not a known configuration error
        raise error
    end
  end
end
