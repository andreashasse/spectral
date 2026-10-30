defmodule Spectral.Error.Redacted do
  @moduledoc false
  # Stands in for `context.value` when a `Spectral.Error` is inspected.
  defstruct []

  defimpl Inspect do
    def inspect(_redacted, _opts), do: "**redacted**"
  end
end

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

  ## Inspecting errors

  `context.value` holds the input that failed, which may contain personal data.
  `inspect/2` (and so `Logger` and IEx) shows it as `**redacted**`, also inside
  the nested errors of a `:no_match` union error. The field itself is unchanged,
  so code can still read `error.context.value`. `Exception.message/1` does not
  include `context.value`.

  Other parts of an error can still carry input data:

  - `location` holds the map keys on the path to the failure, so a map keyed
    by email addresses gives a message like `"type_mismatch at alice@example.com"`.
  - A `:decode_error` context keeps a short piece of the input bytes from the
    JSON parser.
  - Redaction happens only in the Elixir `Inspect` protocol.
    `inspect(error, structs: false)` and Erlang formatting such as `~p` print
    the value.

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
          message: String.t() | nil
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
  def type_mismatch(type, value) do
    {:error,
     [%__MODULE__{type: :type_mismatch, location: [], context: %{type: type, value: value}}]}
  end

  @doc false
  def type_mismatch(type, value, reason) do
    {:error,
     [
       %__MODULE__{
         type: :type_mismatch,
         location: [],
         context: %{type: type, value: value, reason: reason}
       }
     ]}
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

  @doc false
  # Replaces `value` in an error context, and in the contexts of the nested
  # per-branch errors of a `:no_match` error, with a redacted placeholder.
  def redact(%{} = context) do
    context
    |> redact_value()
    |> redact_nested_errors()
  end

  def redact(context), do: context

  defp redact_value(%{value: _} = context), do: %{context | value: %Spectral.Error.Redacted{}}
  defp redact_value(context), do: context

  defp redact_nested_errors(%{errors: errors} = context) when is_list(errors) do
    %{context | errors: Enum.map(errors, &redact_branch/1)}
  end

  defp redact_nested_errors(context), do: context

  defp redact_branch({type, errors}) when is_list(errors),
    do: {type, Enum.map(errors, &redact_error/1)}

  defp redact_error(sp_error(ctx: ctx) = error), do: sp_error(error, ctx: redact(ctx))

  defp format_error(%__MODULE__{location: location, type: type, context: context}) do
    location_str =
      case location do
        [] -> "root"
        path -> Enum.join(path, ".")
      end

    "#{type} at #{location_str}" <> format_hint(context)
  end

  # spectra puts human-readable hints in `context.message`, sometimes as a
  # charlist; `String.Chars` handles both.
  defp format_hint(%{message: message}), do: ": #{message}"
  defp format_hint(_context), do: ""
end

defimpl Inspect, for: Spectral.Error do
  def inspect(%Spectral.Error{context: context} = error, opts) do
    Inspect.Any.inspect(%{error | context: Spectral.Error.redact(context)}, opts)
  end
end
