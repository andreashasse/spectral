defmodule Spectral do
  require Record

  Record.defrecord(
    :type_info,
    Record.extract(:type_info, from_lib: "spectra/include/spectra_internal.hrl")
  )

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

  @typedoc "Spectra type information for a module, imported from the `#type_info{}` Erlang record."
  @type type_info :: record(:type_info)

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

  ## Supported Fields

  - `title` - A short title for the type
  - `description` - A detailed description
  - `examples` - Example values (list, not yet fully supported)
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
  Sets up the Spectral macros and injects `__spectra_type_info__/0` function.

  When you `use Spectral`, the following happens:
  - The `spectral/1` macro is imported for documenting types and functions
  - A `__spectra_type_info__/0` function is injected that returns type information
  - The `@spectral` attribute is registered (used internally by the `spectral/1` macro)

  ## Annotating Types

  Place `spectral/1` immediately before a `@type` definition to attach documentation
  that will appear in generated JSON schemas and OpenAPI component schemas:

      defmodule Person do
        use Spectral

        defstruct [:name, :age]

        spectral title: "Person", description: "A person record"
        @type t :: %Person{name: String.t(), age: non_neg_integer()}
      end

  Types without a `spectral` call will not have title/description in their JSON schemas.

  ### Type Documentation Fields

  - `title` - A short title for the type (string)
  - `description` - A detailed description (string)
  - `examples` - Example values (list, not fully supported yet)

  ## Annotating Functions (Endpoint Documentation)

  Place `spectral/1` immediately before a `@spec` definition to attach endpoint
  documentation. This metadata is used by `Spectral.OpenAPI.endpoint/5` to automatically
  populate the OpenAPI operation fields:

      defmodule MyController do
        use Spectral

        spectral summary: "Get user", description: "Returns a user by ID"
        @spec show(map(), map()) :: map()
        def show(_conn, _params), do: %{}
      end

      # Build the endpoint — docs are read automatically from the function's metadata
      endpoint = Spectral.OpenAPI.endpoint(:get, "/users/{id}", MyController, :show, 2)

  ### Function Documentation Fields

  - `summary` - Short summary of the endpoint operation (string)
  - `description` - Longer description of the operation (string)
  - `deprecated` - Whether the endpoint is deprecated (boolean)

  ## Multiple Annotations

  A module can mix type and function annotations freely:

      defmodule MyModule do
        use Spectral

        spectral title: "Public API", description: "The public interface"
        @type public_api :: map()

        spectral summary: "List items", description: "Returns all items"
        @spec index(map(), map()) :: map()
        def index(_conn, _params), do: %{}
      end

  ## The `__spectra_type_info__/0` Function

  The injected `__spectra_type_info__/0` function returns detailed type information for the module.
  It extracts type definitions from the module's compiled BEAM file and enriches them with
  documentation from `spectral` attributes.

  ### Return Value Structure

  Returns a `type_info` record (Erlang record from spectra library):

      {:type_info, types, records, functions}

  #### Fields:

  - **`types`** - Map of `{type_name, arity}` tuples to `sp_type` records. Each `sp_type` contains:
    - Type structure information (e.g., `sp_map`, `sp_simple_type`, `sp_union`, etc.)
    - A `meta` field containing optional documentation

  - **`records`** - Map of record names (atoms) to `sp_rec` records containing record field information

  - **`functions`** - Map of `{function_name, arity}` tuples to lists of `sp_function_spec` records.
    When annotated with `spectral/1`, each spec's `meta.doc` field holds the endpoint documentation.

  #### Type Documentation (meta field)

  When you use the `spectral` macro to document a type, the documentation is stored in that
  type's `meta` field as:

      %{doc: %{title: "...", description: "...", examples: [...]}}

  #### Function Documentation (sp_function_spec meta field)

  When you use the `spectral` macro to document a function, the documentation is stored in
  each matching `sp_function_spec`'s `meta` field as:

      %{doc: %{summary: "...", description: "..."}}

  Use `Spectral.TypeInfo.get_function_doc/3` to retrieve it.

  ### Example Usage

      defmodule Person do
        use Spectral

        spectral title: "Person", description: "A person record"
        @type t :: %Person{name: String.t()}
      end

      # Access type information
      {:type_info, types, records, functions} = Person.__spectra_type_info__()

      # Get the type definition for Person.t/0
      person_type = types[{:t, 0}]

      # Extract documentation from the type's meta field
      meta = :spectra_type.get_meta(person_type)
      # => %{doc: %{title: "Person", description: "A person record"}}

  ### Use Cases

  This function is primarily used internally by Spectral's encoding, decoding, and schema
  generation functions, but can be called directly for:
  - Introspection and debugging
  - Custom tooling that needs access to type information
  - Documentation generation
  - Type analysis and validation tools
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
    # @type and @typep are stored under separate module attributes; combine them
    # so that spectral/1 annotations can be paired with private types too.
    type_attrs =
      (Module.get_attribute(env.module, :type) || []) ++
        (Module.get_attribute(env.module, :typep) || [])

    spec_attrs = Module.get_attribute(env.module, :spec) || []

    # The :spectral attribute accumulates in reverse order (LIFO), so reverse it to get source order.
    spectral_in_order = Enum.reverse(spectral_attrs)

    types_with_lines =
      type_attrs
      |> Enum.map(fn type_ast ->
        case type_ast do
          {kind, {:"::", meta, [{name, _, args_or_nil}, _type_expr]}, _env}
          when kind in [:type, :typep] and is_atom(name) ->
            arity = if is_list(args_or_nil), do: length(args_or_nil), else: 0
            line = Keyword.get(meta, :line, 0)
            {line, :type, {name, arity}}

          other_ast ->
            type_kind =
              case other_ast do
                {kind, _, _} when is_atom(kind) -> kind
                _ -> :unknown
              end

            raise ArgumentError,
                  "Spectral.__before_compile__/1 encountered unsupported @type AST structure in #{inspect(env.module)}.\n" <>
                    "Type kind: #{inspect(type_kind)}\n" <>
                    "AST: #{inspect(other_ast, pretty: true)}\n\n" <>
                    "This might be a bug in Spectral or an unsupported type definition syntax.\n" <>
                    "Please report this at https://github.com/andreashasse/spectral/issues with the type definition that caused this error."
        end
      end)

    specs_with_lines =
      spec_attrs
      |> Enum.flat_map(fn spec_ast ->
        case spec_ast do
          {:spec, {:"::", meta, [{name, _, args_or_nil}, _return_type]}, _env}
          when is_atom(name) ->
            arity = if is_list(args_or_nil), do: length(args_or_nil), else: 0
            line = Keyword.get(meta, :line, 0)
            [{line, :function, {name, arity}}]

          {:spec, {:when, _, [{:"::", meta, [{name, _, args_or_nil}, _return_type]}, _]}, _env}
          when is_atom(name) ->
            arity = if is_list(args_or_nil), do: length(args_or_nil), else: 0
            line = Keyword.get(meta, :line, 0)
            [{line, :function, {name, arity}}]

          _ ->
            []
        end
      end)

    all_declarations =
      Enum.sort_by(types_with_lines ++ specs_with_lines, fn {line, _, _} -> line end)

    # Semantic pairing: match each @spectral with the @type or @spec that comes immediately after it
    paired_docs =
      Enum.map(spectral_in_order, fn spectral_doc ->
        {spectral_line, doc} =
          case spectral_doc do
            {line, map} when is_integer(line) and is_map(map) ->
              {line, map}

            other ->
              # This should never happen if spectral/1 macro validation is working
              raise ArgumentError,
                    "Internal error: Invalid @spectral attribute format: #{inspect(other)} in #{inspect(env.module)}. " <>
                      "This is a bug in Spectral - please report it at https://github.com/andreashasse/spectral/issues"
          end

        {_decl_line, kind, ref} =
          Enum.find(all_declarations, fn {decl_line, _, _} -> decl_line > spectral_line end) ||
            raise ArgumentError,
                  "spectral call on line #{spectral_line} in #{inspect(env.module)} has no corresponding @type or @spec definition after it"

        {kind, ref, doc}
      end)

    type_docs_to_add =
      paired_docs
      |> Enum.filter(fn {kind, _, _} -> kind == :type end)
      |> Enum.map(fn {:type, {name, arity}, doc} -> {name, arity, doc} end)

    function_docs_to_add =
      paired_docs
      |> Enum.filter(fn {kind, _, _} -> kind == :function end)
      |> Enum.map(fn {:function, {name, arity}, doc} -> {name, arity, doc} end)

    quote do
      def __spectra_type_info__ do
        beam_path =
          case :code.which(__MODULE__) do
            :cover_compiled ->
              {_, _, path} = :code.get_object_code(__MODULE__)
              path

            path when is_list(path) ->
              path

            error ->
              raise ArgumentError,
                    "Cannot find beam file for module #{inspect(__MODULE__)}: #{inspect(error)}"
          end

        type_info = :spectra_abstract_code.types_in_module_path(beam_path)

        type_info_with_type_docs =
          Enum.reduce(
            unquote(Macro.escape(type_docs_to_add)),
            type_info,
            fn {name, arity, doc}, acc_type_info ->
              case :spectra_type_info.find_type(acc_type_info, name, arity) do
                {:ok, existing_type} ->
                  updated_type = :spectra_type.add_doc_to_type(existing_type, doc)
                  :spectra_type_info.add_type(acc_type_info, name, arity, updated_type)

                :error ->
                  acc_type_info
              end
            end
          )

        Enum.reduce(
          unquote(Macro.escape(function_docs_to_add)),
          type_info_with_type_docs,
          fn {name, arity, doc}, acc_type_info ->
            Spectral.__attach_function_doc__(acc_type_info, name, arity, doc)
          end
        )
      end
    end
  end

  @doc false
  def __attach_function_doc__(type_info, name, arity, raw_doc) do
    normalized_doc = :spectra_type.normalize_function_doc(raw_doc)

    case :spectra_type_info.find_function(type_info, name, arity) do
      {:ok, func_specs} ->
        updated_specs =
          Enum.map(func_specs, fn spec ->
            meta = sp_function_spec(spec, :meta)
            sp_function_spec(spec, meta: Map.put(meta, :doc, normalized_doc))
          end)

        :spectra_type_info.add_function(type_info, name, arity, updated_specs)

      :error ->
        type_info
    end
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
  def schema(module, type_ref, format \\ :json_schema) when is_atom(type_ref) do
    # Convert atom type_ref to tuple to preserve type reference for documentation
    # This is a workaround for spectra.erl converting atoms to type structures
    # which bypasses documentation lookup in to_schema
    type_ref_tuple = {:type, type_ref, 0}
    :spectra.schema(format, module, type_ref_tuple)
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

  # Handles Erlang errors from the spectra library and converts configuration
  # errors to idiomatic Elixir ArgumentErrors
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
