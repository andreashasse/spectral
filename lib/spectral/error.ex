defmodule Spectral.Error do
  @moduledoc """
  Exception for Spectral operations.

  This exception represents errors returned from the underlying `:spectra` library,
  converted to an idiomatic Elixir format.

  Can be used both in `{:error, [%Spectral.Error{}]}` tuples and raised as an exception.

  ## Fields

  - `:location` - Path to where the error occurred (list of strings or atoms)
  - `:type` - Type of error (`:decode_error`, `:type_mismatch`, `:no_match`, `:missing_data`, `:not_matched_fields`)
  - `:context` - Additional context information about the error (runtime-determined type)
  - `:message` - Human-readable error message (auto-generated for exceptions)

  ## Example

      %Spectral.Error{
        location: ["user", "age"],
        type: :type_mismatch,
        context: %{expected: :integer, got: "not a number"}
      }
  """

  @type error_type ::
          :decode_error | :type_mismatch | :no_match | :missing_data | :not_matched_fields

  @type t :: %__MODULE__{
          location: [String.t() | atom()],
          type: error_type(),
          context: dynamic(),
          message: String.t()
        }

  defexception [:location, :type, :context, :message]

  @impl true
  def exception(%__MODULE__{} = error) do
    %{error | message: format_error(error)}
  end

  @impl true
  def message(%__MODULE__{} = error) do
    format_error(error)
  end

  @doc """
  Converts an Erlang error record from `:spectra` to a `Spectral.Error` struct.

  ## Parameters

  - `erlang_error` - An error record from the `:spectra` library

  ## Returns

  - `%Spectral.Error{}` - The error as an Elixir struct

  ## Example

      iex> erlang_error = {:sp_error, ["user", "age"], :type_mismatch, %{expected: :integer}}
      iex> Spectral.Error.from_erlang(erlang_error)
      %Spectral.Error{
        location: ["user", "age"],
        type: :type_mismatch,
        context: %{expected: :integer},
        message: nil
      }
  """
  def from_erlang({:sp_error, location, type, ctx}) do
    %__MODULE__{
      location: location,
      type: type,
      context: ctx,
      message: nil
    }
  end

  @doc """
  Converts a list of Erlang error records to Elixir structs.

  ## Parameters

  - `erlang_errors` - A list of error records from the `:spectra` library

  ## Returns

  - `[%Spectral.Error{}]` - List of errors as Elixir structs

  ## Example

      iex> errors = [{:sp_error, [], :decode_error, %{reason: "invalid JSON"}}]
      iex> Spectral.Error.from_erlang_list(errors)
      [%Spectral.Error{location: [], type: :decode_error, context: %{reason: "invalid JSON"}, message: nil}]
  """
  def from_erlang_list(erlang_errors) when is_list(erlang_errors) do
    Enum.map(erlang_errors, &from_erlang/1)
  end

  defp format_error(%__MODULE__{location: location, type: type}) do
    location_str =
      case location do
        [] -> "root"
        path -> Enum.join(path, ".")
      end

    "#{type} at #{location_str}"
  end
end
