defmodule Spectral.TypeInfo do
  @moduledoc """
  Elixir wrapper for the Erlang `:spectra_type_info` module.

  Provides functions for creating and manipulating type information structures
  that contain types, records, and function specifications.

  ## Type Info Structure

  A type_info record (Erlang record from spectra library) has the structure:

      {:type_info, types, records, functions}

  Where:
  - `types` - Map of `{type_name, arity}` tuples to `sp_type` records
  - `records` - Map of record names (atoms) to `sp_rec` records
  - `functions` - Map of `{function_name, arity}` tuples to function spec information

  ## Usage

  Typically, you'll get a type_info structure from a module's `__spectra_type_info__/0` function
  and then query or modify it:

      type_info = Person.__spectra_type_info__()
      
      # Find a specific type
      case Spectral.TypeInfo.find_type(type_info, :t, 0) do
        {:ok, type} -> IO.inspect(type)
        :error -> IO.puts("Type not found")
      end

      # Add a new type
      new_type_info = Spectral.TypeInfo.add_type(type_info, :custom, 0, custom_type)

  ## Type Keys

  Types and functions are indexed by tuples of `{name :: atom(), arity :: non_neg_integer()}`.
  Records are indexed by their name (atom).
  """

  @type type_info :: :spectra_type_info.type_info()
  @type type_key :: :spectra_type_info.type_key()
  @type function_key :: :spectra_type_info.function_key()

  @doc """
  Creates a new empty type_info structure.

  ## Examples

      iex> type_info = Spectral.TypeInfo.new()
      iex> is_tuple(type_info)
      true
  """
  @spec new() :: type_info()
  def new do
    :spectra_type_info.new()
  end

  @doc """
  Adds a type to the type_info structure.

  ## Parameters

  - `type_info` - The type_info structure to add to
  - `name` - The type name (atom)
  - `arity` - The type arity (non-negative integer)
  - `type` - The sp_type record to add

  ## Returns

  Updated type_info structure with the type added.

  ## Examples

      iex> type_info = Person.__spectra_type_info__()
      iex> {:ok, person_type} = Spectral.TypeInfo.find_type(type_info, :t, 0)
      iex> new_info = Spectral.TypeInfo.new()
      iex> updated = Spectral.TypeInfo.add_type(new_info, :my_type, 0, person_type)
      iex> {:ok, _type} = Spectral.TypeInfo.find_type(updated, :my_type, 0)
      iex> :ok
      :ok
  """
  @spec add_type(type_info(), atom(), arity(), term()) :: type_info()
  def add_type(type_info, name, arity, type) when is_atom(name) and is_integer(arity) do
    :spectra_type_info.add_type(type_info, name, arity, type)
  end

  @doc """
  Finds a type in the type_info structure.

  ## Parameters

  - `type_info` - The type_info structure to search
  - `name` - The type name (atom)
  - `arity` - The type arity (non-negative integer)

  ## Returns

  - `{:ok, type}` - If the type is found
  - `:error` - If the type is not found

  ## Examples

      iex> type_info = Person.__spectra_type_info__()
      iex> {:ok, type} = Spectral.TypeInfo.find_type(type_info, :t, 0)
      iex> is_tuple(type)
      true
      
      iex> type_info = Spectral.TypeInfo.new()
      iex> Spectral.TypeInfo.find_type(type_info, :nonexistent, 0)
      :error
  """
  @spec find_type(type_info(), atom(), arity()) :: {:ok, term()} | :error
  def find_type(type_info, name, arity) when is_atom(name) and is_integer(arity) do
    :spectra_type_info.find_type(type_info, name, arity)
  end

  @doc """
  Gets a type from the type_info structure, raising if not found.

  ## Parameters

  - `type_info` - The type_info structure to search
  - `name` - The type name (atom)
  - `arity` - The type arity (non-negative integer)

  ## Returns

  The sp_type record.

  ## Raises

  - `ErlangError` with `{:type_not_found, name, arity}` if the type doesn't exist

  ## Examples

      iex> type_info = Person.__spectra_type_info__()
      iex> type = Spectral.TypeInfo.get_type(type_info, :t, 0)
      iex> is_tuple(type)
      true
  """
  @spec get_type(type_info(), atom(), arity()) :: term()
  def get_type(type_info, name, arity) when is_atom(name) and is_integer(arity) do
    :spectra_type_info.get_type(type_info, name, arity)
  end

  @doc """
  Adds a record to the type_info structure.

  ## Parameters

  - `type_info` - The type_info structure to add to
  - `name` - The record name (atom)
  - `record` - The sp_rec record to add

  ## Returns

  Updated type_info structure with the record added.

  ## Examples

      type_info = Spectral.TypeInfo.new()
      updated = Spectral.TypeInfo.add_record(type_info, :my_record, some_record)
  """
  @spec add_record(type_info(), atom(), term()) :: type_info()
  def add_record(type_info, name, record) when is_atom(name) do
    :spectra_type_info.add_record(type_info, name, record)
  end

  @doc """
  Finds a record in the type_info structure.

  ## Parameters

  - `type_info` - The type_info structure to search
  - `name` - The record name (atom)

  ## Returns

  - `{:ok, record}` - If the record is found
  - `:error` - If the record is not found

  ## Examples

      iex> type_info = Spectral.TypeInfo.new()
      iex> Spectral.TypeInfo.find_record(type_info, :person)
      :error
  """
  @spec find_record(type_info(), atom()) :: {:ok, term()} | :error
  def find_record(type_info, name) when is_atom(name) do
    :spectra_type_info.find_record(type_info, name)
  end

  @doc """
  Gets a record from the type_info structure, raising if not found.

  ## Parameters

  - `type_info` - The type_info structure to search
  - `name` - The record name (atom)

  ## Returns

  The sp_rec record.

  ## Raises

  - `ErlangError` with `{:record_not_found, name}` if the record doesn't exist

  ## Examples

      type_info = Person.__spectra_type_info__()
      record = Spectral.TypeInfo.get_record(type_info, :person)
  """
  @spec get_record(type_info(), atom()) :: term()
  def get_record(type_info, name) when is_atom(name) do
    :spectra_type_info.get_record(type_info, name)
  end

  @doc """
  Adds a function specification to the type_info structure.

  ## Parameters

  - `type_info` - The type_info structure to add to
  - `name` - The function name (atom)
  - `arity` - The function arity (non-negative integer)
  - `func_spec` - The function spec to add (list of sp_function_spec records)

  ## Returns

  Updated type_info structure with the function spec added.

  ## Examples

      type_info = Spectral.TypeInfo.new()
      updated = Spectral.TypeInfo.add_function(type_info, :my_func, 2, func_spec)
  """
  @spec add_function(type_info(), atom(), arity(), [term()]) :: type_info()
  def add_function(type_info, name, arity, func_spec)
      when is_atom(name) and is_integer(arity) and is_list(func_spec) do
    :spectra_type_info.add_function(type_info, name, arity, func_spec)
  end

  @doc """
  Finds a function specification in the type_info structure.

  ## Parameters

  - `type_info` - The type_info structure to search
  - `name` - The function name (atom)
  - `arity` - The function arity (non-negative integer)

  ## Returns

  - `{:ok, func_spec}` - If the function spec is found (list of sp_function_spec records)
  - `:error` - If the function spec is not found

  ## Examples

      iex> type_info = Spectral.TypeInfo.new()
      iex> Spectral.TypeInfo.find_function(type_info, :my_func, 2)
      :error
  """
  @spec find_function(type_info(), atom(), arity()) :: {:ok, [term()]} | :error
  def find_function(type_info, name, arity) when is_atom(name) and is_integer(arity) do
    :spectra_type_info.find_function(type_info, name, arity)
  end
end
