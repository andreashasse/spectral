defmodule Spectral do
  @moduledoc """
  Documentation for `Spectral`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Spectral.hello()
      :world

  """
  def hello do
    :world
  end

  @doc """
  Encodes data to the specified format.

  ## Examples

      iex> {:ok, jsondata} = Spectral.encode(:json, Person, :t, %Person{name: "Alice", age: 30, address: %Person.Address{street: "Ystader Straße", city: "Berlin"}})
      iex> IO.iodata_to_binary(jsondata)
      ~s({"address":{"city":"Berlin","street":"Ystader Straße"},"age":30,"name":"Alice"})

      iex> {:ok, jsondata} = Spectral.encode(:json, Person, :t, %Person{name: "Alice"})
      iex> IO.iodata_to_binary(jsondata)
      ~s({"name":"Alice"})
  """
  def encode(format, module, type_ref, data) do
    :spectra.encode(format, module, type_ref, data)
  end

  @doc """
  Decodes data from the specified format.
  ## Examples

      iex> Spectral.decode(:json, Person, :t, ~s({"name":"Alice","age":30,"address":{"street":"Ystader Straße", "city": "Berlin"}}))
      {:ok, %Person{age: 30, name: "Alice", address: %Person.Address{street: "Ystader Straße", city: "Berlin"}}}

      iex> Spectral.decode(:json, Person, :t, ~s({"name":"Alice"}))
      {:ok, %Person{age: nil, name: "Alice"}}
  """
  def decode(format, module, type_ref, data) do
    :spectra.decode(format, module, type_ref, data)
  end

  @doc """
  Generates a schema for the specified format.
  ## Examples

      iex> {:ok, schemadata} = Spectral.schema(:json_schema, Person, :t)
      iex> IO.iodata_to_binary(schemadata)
  """
  def schema(format, module, type_ref) do
    :spectra.schema(format, module, type_ref)
  end
end
