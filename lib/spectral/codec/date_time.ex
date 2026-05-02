defmodule Spectral.Codec.DateTime do
  @moduledoc """
  Built-in codec for `DateTime.t()`.

  Encodes `DateTime` structs to ISO 8601 / RFC 3339 strings
  (e.g. `"2012-04-23T18:25:43.511Z"`) and decodes them back.
  Handles `:json` and `:binary_string` formats (returning a binary string) and
  `:string` format (returning a charlist).

  ## Registration

  Register this codec in your application's `config/config.exs` or
  `application.ex` start callback before encoding/decoding `DateTime` values:

      Application.put_env(:spectra, :codecs, %{
        {DateTime, {:type, :t, 0}} => Spectral.Codec.DateTime
      })
  """

  use Spectral.Codec

  @impl Spectral.Codec
  def encode(format, _caller_type_info, {:type, :t, 0}, _target_type, %DateTime{} = dt, _config)
      when format in [:json, :binary_string] do
    {:ok, DateTime.to_iso8601(dt)}
  end

  def encode(:string, _caller_type_info, {:type, :t, 0}, _target_type, %DateTime{} = dt, _config) do
    {:ok, String.to_charlist(DateTime.to_iso8601(dt))}
  end

  def encode(_format, _caller_type_info, {:type, :t, 0}, _target_type, data, _config) do
    {:error,
     [
       %Spectral.Error{
         type: :type_mismatch,
         location: [],
         context: %{type: {:type, :t, 0}, value: data}
       }
     ]}
  end

  @impl Spectral.Codec
  def decode(format, _caller_type_info, {:type, :t, 0}, _target_type, input, _config)
      when format in [:json, :binary_string] and is_binary(input) do
    case DateTime.from_iso8601(input) do
      {:ok, dt, _offset} ->
        {:ok, dt}

      {:error, _} ->
        {:error,
         [
           %Spectral.Error{
             type: :type_mismatch,
             location: [],
             context: %{type: {:type, :t, 0}, value: input, reason: :invalid_format}
           }
         ]}
    end
  end

  def decode(:string, _caller_type_info, {:type, :t, 0}, _target_type, input, _config)
      when is_list(input) do
    case DateTime.from_iso8601(List.to_string(input)) do
      {:ok, dt, _offset} ->
        {:ok, dt}

      {:error, _} ->
        {:error,
         [
           %Spectral.Error{
             type: :type_mismatch,
             location: [],
             context: %{type: {:type, :t, 0}, value: input, reason: :invalid_format}
           }
         ]}
    end
  end

  def decode(_format, _caller_type_info, {:type, :t, 0}, _target_type, data, _config) do
    {:error,
     [
       %Spectral.Error{
         type: :type_mismatch,
         location: [],
         context: %{type: {:type, :t, 0}, value: data}
       }
     ]}
  end

  @impl Spectral.Codec
  def schema(_format, _caller_type_info, {:type, :t, 0}, _target_type, _config) do
    %{type: "string", format: "date-time"}
  end
end
