defmodule Spectral do
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

  defmacro spectral(metadata) do
    line = __CALLER__.line

    quote do
      @spectral {unquote(line), unquote(metadata)}
    end
  end

  @doc """
  Sets up the Spectral macros and injects `__spectra__/0` function.

  When you `use Spectral`, the following happens:
  - The `spectral/1` macro is imported for documenting types
  - A `__spectra__/0` function is injected that returns type information
  - The `@spectral` attribute is registered (used internally by the `spectral/1` macro)

  ## Usage

  Use the `spectral/1` macro to document types. Place it immediately before a `@type` definition:

      defmodule Person do
        use Spectral

        defstruct [:name, :age]

        spectral title: "Person", description: "A person record"
        @type t :: %Person{name: String.t(), age: non_neg_integer()}
      end

  Types without a `spectral` call will not have title/description in their JSON schemas.

  ## Documentation Fields

  The `spectral` macro accepts the following fields:
  - `title` - A short title for the type (string)
  - `description` - A detailed description (string)
  - `examples` - Example values (list, not fully supported yet)

  ## Multiple Types

  You can have multiple types in a module. Only document the ones you want:

      defmodule MyModule do
        use Spectral

        # Public API type - documented
        spectral title: "Public API", description: "The public interface"
        @type public_api :: map()

        # Internal type - no documentation needed
        @type internal_id :: non_neg_integer()
      end

  ## The `__spectra__/0` Function

  The injected `__spectra__/0` function returns detailed type information for the module.
  It calls `:spectra_abstract_code.types_in_module/1` and returns a tuple with the structure:

      {:type_info, types_map, docs_map, specs_map, callbacks_map}

  Where:
  - `types_map` - Map of `{type_name, arity}` to type AST information
  - `docs_map` - Map containing documentation from `spectral` calls (title, description, etc.)
  - `specs_map` - Map of function specs
  - `callbacks_map` - Map of callback specs

  Example:

      Person.__spectra__()
      # => {:type_info, %{{:t, 0} => ...}, %{title: "Person", ...}, %{}, %{}}

  This function is primarily used internally by Spectral's encoding, decoding, and schema
  generation functions, but can be called directly for introspection purposes.
  """
  defmacro __using__(_opts) do
    quote do
      Module.register_attribute(__MODULE__, :spectral, accumulate: true, persist: true)
      import Spectral, only: [spectral: 1]
      @before_compile Spectral
    end
  end

  @doc false
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
  # credo:disable-for-this-file Credo.Check.Refactor.Nesting
  defmacro __before_compile__(env) do
    spectral_attrs = Module.get_attribute(env.module, :spectral) || []
    type_attrs = Module.get_attribute(env.module, :type) || []

    # Both attributes accumulate in reverse order (LIFO), so reverse to get source order
    spectral_in_order = Enum.reverse(spectral_attrs)

    # Extract types with their line numbers from the AST metadata
    types_with_lines =
      type_attrs
      |> Enum.reverse()
      |> Enum.map(fn
        {:type, {:"::", meta, [{name, _, args_or_nil}, _]}, _} ->
          arity = if is_list(args_or_nil), do: length(args_or_nil), else: 0
          line = Keyword.get(meta, :line, 0)
          {line, {name, arity}}

        other_ast ->
          raise ArgumentError,
                "Spectral.__before_compile__/1 encountered unsupported @type AST in " <>
                  "#{inspect(env.module)}: #{inspect(other_ast)}. " <>
                  "Please report this as a bug at https://github.com/andreashasse/spectral/issues"
      end)

    # Semantic pairing: match each @spectral with the @type that comes immediately after it
    # For each @spectral, find the first @type defined on a later line
    paired_docs =
      Enum.map(spectral_in_order, fn spectral_doc ->
        # Extract line number and doc - crash if format is unexpected
        {spectral_line, doc} =
          case spectral_doc do
            {line, map} when is_integer(line) and is_map(map) ->
              {line, map}

            other ->
              raise ArgumentError,
                    "spectral macro must be called with keyword list or map, got: #{inspect(other)} in #{inspect(env.module)}"
          end

        # Find the first type defined after this @spectral - crash if not found
        {_type_line, type_ref} =
          Enum.find(types_with_lines, fn {type_line, _} -> type_line > spectral_line end) ||
            raise ArgumentError,
                  "spectral call on line #{spectral_line} in #{inspect(env.module)} has no corresponding @type definition after it"

        Map.put(doc, :type, type_ref)
      end)

    # Prepare docs for injection into the __spectra__ function
    # Convert paired_docs into a list of {name, arity, doc} tuples
    docs_to_add =
      Enum.map(paired_docs, fn doc ->
        # Extract type name and arity from the :type field
        {type_name, type_arity} = doc[:type]
        # Remove the :type field from the doc map (it's metadata, not part of the doc)
        doc_without_type = Map.delete(doc, :type)
        {type_name, type_arity, doc_without_type}
      end)

    quote do
      def __spectra__ do
        # Get the beam file path for this module
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

        # Load type info from the beam file
        type_info = :spectra_abstract_code.types_in_module_path(beam_path)

        # Add each doc to the type_info using :spectra_type_info.add_doc/4
        Enum.reduce(
          unquote(Macro.escape(docs_to_add)),
          type_info,
          fn {name, arity, doc}, acc_type_info ->
            :spectra_type_info.add_doc(acc_type_info, name, arity, doc)
          end
        )
      end
    end
  end

  @doc """
  Encodes data to the specified format.

  ## Parameters

  - `data` - The data to encode
  - `module` - Module containing the type definition
  - `type_ref` - Type reference (typically an atom like `:t`)
  - `format` - Format to encode to (default: `:json`)

  ## Returns

  - `{:ok, iodata()}` - Encoded data on success
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
  """
  @spec encode(dynamic(), module(), atom(), atom()) ::
          {:ok, iodata()} | {:error, [Spectral.Error.t()]}
  def encode(data, module, type_ref, format \\ :json) do
    :spectra.encode(format, module, type_ref, data)
    |> convert_result()
  rescue
    error in ErlangError ->
      handle_erlang_error(error, :encode, module, type_ref)
  end

  @doc """
  Decodes data from the specified format.

  ## Parameters

  - `data` - The data to decode (binary for JSON, string for string format)
  - `module` - Module containing the type definition
  - `type_ref` - Type reference (typically an atom like `:t`)
  - `format` - Format to decode from (default: `:json`)

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
  """
  @spec decode(binary(), module(), atom(), atom()) ::
          {:ok, dynamic()} | {:error, [Spectral.Error.t()]}
  def decode(data, module, type_ref, format \\ :json) do
    :spectra.decode(format, module, type_ref, data)
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
  @spec schema(module(), atom(), atom()) :: iodata()
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

  Like `encode/4` but raises `Spectral.Error` instead of returning an error tuple.

  ## Parameters

  - `data` - The data to encode
  - `module` - Module containing the type definition
  - `type_ref` - Type reference (typically an atom like `:t`)
  - `format` - Format to encode to (default: `:json`)

  ## Returns

  - `iodata()` - Encoded data on success

  ## Raises

  - `Spectral.Error` - If encoding fails

  ## Examples

      iex> %Person{name: "Alice", age: 30}
      ...> |> Spectral.encode!(Person, :t)
      ...> |> IO.iodata_to_binary()
      ~s({"age":30,"name":"Alice"})
  """
  @spec encode!(dynamic(), module(), atom(), atom()) :: iodata()
  def encode!(data, module, type_ref, format \\ :json) do
    case encode(data, module, type_ref, format) do
      {:ok, result} ->
        result

      {:error, [error | _]} ->
        raise Spectral.Error.exception(error)
    end
  end

  @doc """
  Decodes data from the specified format, raising on error.

  Like `decode/4` but raises `Spectral.Error` instead of returning an error tuple.

  ## Parameters

  - `data` - The data to decode (binary for JSON, string for string format)
  - `module` - Module containing the type definition
  - `type_ref` - Type reference (typically an atom like `:t`)
  - `format` - Format to decode from (default: `:json`)

  ## Returns

  - `dynamic()` - Decoded data on success

  ## Raises

  - `Spectral.Error` - If decoding fails

  ## Examples

      iex> ~s({"name":"Alice","age":30})
      ...> |> Spectral.decode!(Person, :t)
      %Person{age: 30, name: "Alice", address: nil}
  """
  @spec decode!(binary(), module(), atom(), atom()) :: dynamic()
  def decode!(data, module, type_ref, format \\ :json) do
    case decode(data, module, type_ref, format) do
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
