defmodule Spectral.Codec.String do
  @moduledoc """
  Built-in codec for `String.t()`.

  Validates that encoded and decoded values are UTF-8 binaries, and optionally
  enforces constraints supplied via `type_parameters` in a `spectral` annotation
  placed before the type definition:

  - `min_length` — minimum codepoint length (inclusive)
  - `max_length` — maximum codepoint length (inclusive)
  - `pattern` — regular expression the string must match

  When no params are present the codec acts as a transparent pass-through,
  accepting any binary and producing it unchanged.

  Note: `type_parameters` are only accessible when the codec is invoked directly
  from a `Spectral` entry point (e.g. `Spectral.encode/decode` called with the
  type's own module). They are not propagated during mid-traversal dispatch.

  ## Registration

  Register this codec in your application's `config/config.exs` or
  `application.ex` start callback before encoding/decoding `String.t()` values:

      Application.put_env(:spectra, :codecs, %{
        {String, {:type, :t, 0}} => Spectral.Codec.String
      })
  """

  use Spectral.Codec

  @impl Spectral.Codec
  def encode(_format, _caller_type_info, {:type, :t, 0}, target_type, data, _config)
      when is_binary(data) do
    validate(data, :spectra_type.parameters(target_type))
  end

  def encode(_format, _caller_type_info, {:type, :t, 0}, _target_type, data, _config) do
    Spectral.Error.type_mismatch({:type, :t, 0}, data)
  end

  @impl Spectral.Codec
  def decode(_format, _caller_type_info, {:type, :t, 0}, target_type, input, _config)
      when is_binary(input) do
    validate(input, :spectra_type.parameters(target_type))
  end

  def decode(_format, _caller_type_info, {:type, :t, 0}, _target_type, input, _config) do
    Spectral.Error.type_mismatch({:type, :t, 0}, input)
  end

  @impl Spectral.Codec
  def schema(_format, _caller_type_info, {:type, :t, 0}, target_type, _config) do
    base = %{type: "string"}

    case :spectra_type.parameters(target_type) do
      :undefined ->
        base

      %{} = params ->
        base
        |> maybe_put(:minLength, params[:min_length])
        |> maybe_put(:maxLength, params[:max_length])
        |> maybe_put(:pattern, params[:pattern])
        |> maybe_put(:format, params[:format])
    end
  end

  defp validate(input, :undefined), do: {:ok, input}

  defp validate(input, params) do
    with :ok <- check_min_length(input, params[:min_length]),
         :ok <- check_max_length(input, params[:max_length]),
         :ok <- check_pattern(input, params[:pattern]) do
      {:ok, input}
    end
  end

  defp check_min_length(_input, nil), do: :ok

  defp check_min_length(input, min) do
    if String.length(input) >= min,
      do: :ok,
      else:
        {:error,
         [
           %Spectral.Error{
             type: :type_mismatch,
             location: [],
             context: %{type: {:type, :t, 0}, value: input, reason: :min_length, min_length: min}
           }
         ]}
  end

  defp check_max_length(_input, nil), do: :ok

  defp check_max_length(input, max) do
    if String.length(input) <= max,
      do: :ok,
      else:
        {:error,
         [
           %Spectral.Error{
             type: :type_mismatch,
             location: [],
             context: %{type: {:type, :t, 0}, value: input, reason: :max_length, max_length: max}
           }
         ]}
  end

  defp check_pattern(_input, nil), do: :ok

  defp check_pattern(input, pattern) when is_binary(pattern) do
    if Regex.match?(Regex.compile!(pattern), input),
      do: :ok,
      else:
        {:error,
         [
           %Spectral.Error{
             type: :type_mismatch,
             location: [],
             context: %{type: {:type, :t, 0}, value: input, reason: :pattern, pattern: pattern}
           }
         ]}
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
