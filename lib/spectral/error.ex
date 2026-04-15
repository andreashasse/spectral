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

  # Import Erlang record definition from spectra
  require Record

  Record.defrecordp(
    :sp_error,
    Record.extract(:sp_error, from_lib: "spectra/include/spectra.hrl")
  )

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

  @doc false
  def from_erlang(sp_error(location: location, type: type, ctx: ctx)) do
    %__MODULE__{
      location: location,
      type: type,
      context: ctx,
      message: nil
    }
  end

  @doc false
  def from_erlang_list(erlang_errors) when is_list(erlang_errors) do
    Enum.map(erlang_errors, &from_erlang/1)
  end

  @doc false
  def to_erlang(%__MODULE__{location: location, type: type, context: ctx}) do
    sp_error(type: type, location: location, ctx: ctx || %{})
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
