defmodule Spectral.TypeInfo do
  require Record

  Record.defrecord(
    :sp_function_spec,
    Record.extract(:sp_function_spec, from_lib: "spectra/include/spectra_internal.hrl")
  )

  @moduledoc """
  Elixir wrapper for the Erlang `:spectra_type_info` module.

  Provides functions for creating and manipulating type information structures
  that contain types, records, and function specifications.

  > #### Advanced integrations {: .info}
  >
  > This module is intended for advanced integrations, such as building custom
  > web framework plugins or other tooling on top of Spectral. Most applications
  > will not need to use it directly.

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
  Creates a new type_info structure for the given module.

  Pass `implements_codec: true` when the module implements `Spectral.Codec`.
  In practice you rarely need to call this directly — type info is normally
  obtained via `Module.__spectra_type_info__/0`.

  ## Examples

      iex> type_info = Spectral.TypeInfo.new(Person, false)
      iex> Spectral.TypeInfo.get_module(type_info)
      Person
  """
  @spec new(module(), boolean()) :: type_info()
  def new(module, implements_codec) when is_atom(module) and is_boolean(implements_codec) do
    :spectra_type_info.new(module, implements_codec)
  end

  @doc """
  Returns the module associated with a type_info structure.

  ## Examples

      iex> type_info = Person.__spectra_type_info__()
      iex> Spectral.TypeInfo.get_module(type_info)
      Person
  """
  @spec get_module(type_info()) :: module()
  def get_module(type_info) do
    :spectra_type_info.get_module(type_info)
  end

  @doc """
  Adds a type to the type_info structure.

  ## Examples

      iex> type_info = Person.__spectra_type_info__()
      iex> {:ok, person_type} = Spectral.TypeInfo.find_type(type_info, :t, 0)
      iex> new_info = Spectral.TypeInfo.new(:nomodule, false)
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
  Finds a type in the type_info structure. Returns `{:ok, type}` or `:error`.

  ## Examples

      iex> type_info = Person.__spectra_type_info__()
      iex> {:ok, type} = Spectral.TypeInfo.find_type(type_info, :t, 0)
      iex> is_tuple(type)
      true

      iex> type_info = Spectral.TypeInfo.new(:nomodule, false)
      iex> Spectral.TypeInfo.find_type(type_info, :nonexistent, 0)
      :error
  """
  @spec find_type(type_info(), atom(), arity()) :: {:ok, term()} | :error
  def find_type(type_info, name, arity) when is_atom(name) and is_integer(arity) do
    :spectra_type_info.find_type(type_info, name, arity)
  end

  @doc """
  Gets a type from the type_info structure, raising `{:type_not_found, name, arity}` if absent.

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
  """
  @spec add_record(type_info(), atom(), term()) :: type_info()
  def add_record(type_info, name, record) when is_atom(name) do
    :spectra_type_info.add_record(type_info, name, record)
  end

  @doc """
  Finds a record in the type_info structure. Returns `{:ok, record}` or `:error`.

  ## Examples

      iex> type_info = Spectral.TypeInfo.new(:nomodule, false)
      iex> Spectral.TypeInfo.find_record(type_info, :person)
      :error
  """
  @spec find_record(type_info(), atom()) :: {:ok, term()} | :error
  def find_record(type_info, name) when is_atom(name) do
    :spectra_type_info.find_record(type_info, name)
  end

  @doc """
  Gets a record from the type_info structure, raising `{:record_not_found, name}` if absent.
  """
  @spec get_record(type_info(), atom()) :: term()
  def get_record(type_info, name) when is_atom(name) do
    :spectra_type_info.get_record(type_info, name)
  end

  @doc """
  Adds a function specification to the type_info structure.
  """
  @spec add_function(type_info(), atom(), arity(), [term()]) :: type_info()
  def add_function(type_info, name, arity, func_spec)
      when is_atom(name) and is_integer(arity) and is_list(func_spec) do
    :spectra_type_info.add_function(type_info, name, arity, func_spec)
  end

  @doc """
  Finds a function specification in the type_info structure. Returns `{:ok, specs}` or `:error`.

  ## Examples

      iex> type_info = Spectral.TypeInfo.new(:nomodule, false)
      iex> Spectral.TypeInfo.find_function(type_info, :my_func, 2)
      :error
  """
  @spec find_function(type_info(), atom(), arity()) :: {:ok, [term()]} | :error
  def find_function(type_info, name, arity) when is_atom(name) and is_integer(arity) do
    :spectra_type_info.find_function(type_info, name, arity)
  end

  @doc """
  Returns the endpoint documentation attached to a function via the `spectral/1` macro.

  When `spectral/1` is placed before a `@spec` and function definition, the documentation
  map (with keys like `:summary`, `:description`, `:deprecated`) is stored in the function
  spec's metadata. This function retrieves it, using the first function spec when there are
  multiple specs (e.g., multiple clauses with different guards).

  ## Parameters

  - `type_info` - The type_info structure to search
  - `name` - The function name (atom)
  - `arity` - The function arity (non-negative integer)

  ## Returns

  - `{:ok, doc}` - If a doc was attached to the function (map with endpoint doc fields)
  - `{:error, :no_doc_found}` - If the function exists but has no `spectral/1` annotation
  - `{:error, :function_not_found}` - If the function is not found in the type info

  ## Example

      type_info = MyController.__spectra_type_info__()
      {:ok, doc} = Spectral.TypeInfo.get_function_doc(type_info, :show, 2)
      # doc => %{summary: "Show resource", description: "Returns a resource by ID"}
  """
  @spec get_function_doc(type_info(), atom(), arity()) ::
          {:ok, map()} | {:error, :no_doc_found | :function_not_found}
  def get_function_doc(type_info, name, arity) when is_atom(name) and is_integer(arity) do
    case :spectra_type_info.find_function(type_info, name, arity) do
      {:ok, [spec | _]} ->
        meta = sp_function_spec(spec, :meta)

        case Map.fetch(meta, :doc) do
          {:ok, doc} -> {:ok, doc}
          :error -> {:error, :no_doc_found}
        end

      _ ->
        {:error, :function_not_found}
    end
  end
end
