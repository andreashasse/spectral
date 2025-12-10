defmodule Spectral do
  @moduledoc """
  Elixir wrapper for the Erlang `spectra` library.

  Provides idiomatic Elixir interfaces for encoding, decoding, and schema generation
  based on type specifications.

  ## Pipe-Friendly API

  All functions are designed to work well with Elixir's pipe operator:

      %Person{name: "Alice", age: 30}
      |> Spectral.encode(Person, :t)
      |> case do
        {:ok, json} -> IO.iodata_to_binary(json)
        {:error, errors} -> handle_errors(errors)
      end

  ## Error Handling

  All functions return `{:ok, result}` or `{:error, [%Spectral.Error{}]}`.
  Errors are converted from Erlang records to Elixir structs for better usability.
  """

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

      iex> %Person{name: "Alice", age: 30, address: %Person.Address{street: "Ystader Straße", city: "Berlin"}}
      ...> |> Spectral.encode(Person, :t)
      ...> |> elem(1)
      ...> |> IO.iodata_to_binary()
      ~s({"address":{"city":"Berlin","street":"Ystader Straße"},"age":30,"name":"Alice"})

      iex> %Person{name: "Alice"}
      ...> |> Spectral.encode(Person, :t)
      ...> |> elem(1)
      ...> |> IO.iodata_to_binary()
      ~s({"name":"Alice"})
  """
  @spec encode(term(), module(), atom(), atom()) ::
          {:ok, iodata()} | {:error, [Spectral.Error.t()]}
  def encode(data, module, type_ref, format \\ :json) do
    format
    |> :spectra.encode(module, type_ref, data)
    |> convert_result()
  end

  @doc """
  Decodes data from the specified format.

  ## Parameters

  - `data` - The data to decode (binary for JSON, string for string format)
  - `module` - Module containing the type definition
  - `type_ref` - Type reference (typically an atom like `:t`)
  - `format` - Format to decode from (default: `:json`)

  ## Returns

  - `{:ok, term()}` - Decoded data on success
  - `{:error, [%Spectral.Error{}]}` - List of errors on failure

  ## Examples

      iex> ~s({"name":"Alice","age":30,"address":{"street":"Ystader Straße", "city": "Berlin"}})
      ...> |> Spectral.decode(Person, :t)
      {:ok, %Person{age: 30, name: "Alice", address: %Person.Address{street: "Ystader Straße", city: "Berlin"}}}

      iex> ~s({"name":"Alice"})
      ...> |> Spectral.decode(Person, :t)
      {:ok, %Person{age: nil, name: "Alice", address: nil}}
  """
  @spec decode(term(), module(), atom(), atom()) ::
          {:ok, term()} | {:error, [Spectral.Error.t()]}
  def decode(data, module, type_ref, format \\ :json) do
    format
    |> :spectra.decode(module, type_ref, data)
    |> convert_result()
  end

  @doc """
  Generates a schema for the specified type.

  ## Parameters

  - `module` - Module containing the type definition
  - `type_ref` - Type reference (typically an atom like `:t`)
  - `format` - Schema format (default: `:json_schema`)

  ## Returns

  - `{:ok, iodata()}` - Generated schema on success
  - `{:error, [%Spectral.Error{}]}` - List of errors on failure

  ## Examples

      iex> {:ok, schemadata} = Spectral.schema(Person, :t)
      iex> is_binary(IO.iodata_to_binary(schemadata))
      true
  """
  @spec schema(module(), atom(), atom()) ::
          {:ok, iodata()} | {:error, [Spectral.Error.t()]}
  def schema(module, type_ref, format \\ :json_schema) do
    format
    |> :spectra.schema(module, type_ref)
    |> convert_result()
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
  @spec encode!(term(), module(), atom(), atom()) :: iodata()
  def encode!(data, module, type_ref, format \\ :json) do
    case encode(data, module, type_ref, format) do
      {:ok, result} -> result
      {:error, [error | _]} -> raise error
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

  - `term()` - Decoded data on success

  ## Raises

  - `Spectral.Error` - If decoding fails

  ## Examples

      iex> ~s({"name":"Alice","age":30})
      ...> |> Spectral.decode!(Person, :t)
      %Person{age: 30, name: "Alice", address: nil}
  """
  @spec decode!(term(), module(), atom(), atom()) :: term()
  def decode!(data, module, type_ref, format \\ :json) do
    case decode(data, module, type_ref, format) do
      {:ok, result} -> result
      {:error, [error | _]} -> raise error
    end
  end

  @doc """
  Generates a schema for the specified type, raising on error.

  Like `schema/3` but raises `Spectral.Error` instead of returning an error tuple.

  ## Parameters

  - `module` - Module containing the type definition
  - `type_ref` - Type reference (typically an atom like `:t`)
  - `format` - Schema format (default: `:json_schema`)

  ## Returns

  - `iodata()` - Generated schema on success

  ## Raises

  - `Spectral.Error` - If schema generation fails

  ## Examples

      iex> schemadata = Spectral.schema!(Person, :t)
      iex> is_binary(IO.iodata_to_binary(schemadata))
      true
  """
  @spec schema!(module(), atom(), atom()) :: iodata()
  def schema!(module, type_ref, format \\ :json_schema) do
    case schema(module, type_ref, format) do
      {:ok, result} -> result
      {:error, [error | _]} -> raise error
    end
  end

  # Private helper to convert Erlang results to Elixir
  defp convert_result({:ok, result}), do: {:ok, result}

  defp convert_result({:error, erlang_errors}) when is_list(erlang_errors) do
    {:error, Spectral.Error.from_erlang_list(erlang_errors)}
  end
end
