defmodule Spectral.Codec.Date do
  @moduledoc """
  Built-in codec for `Date.t()`.

  Encodes `Date` structs to ISO 8601 strings (e.g. `"2023-04-01"`) and decodes
  them back. Handles `:json` and `:binary_string` formats (returning a binary string)
  and `:string` format (returning a charlist).

  ## Registration

  Register this codec in your application's `config/config.exs` or
  `application.ex` start callback before encoding/decoding `Date` values:

      Application.put_env(:spectra, :codecs, %{
        {Date, {:type, :t, 0}} => Spectral.Codec.Date
      })
  """

  use Spectral.Codec

  @type_ref {:type, :t, 0}

  @impl Spectral.Codec
  def encode(format, _caller_type_info, {:type, :t, 0}, _target_type, %Date{} = d, _config)
      when format in [:json, :binary_string] do
    {:ok, Date.to_iso8601(d)}
  end

  def encode(:string, _caller_type_info, {:type, :t, 0}, _target_type, %Date{} = d, _config) do
    {:ok, String.to_charlist(Date.to_iso8601(d))}
  end

  def encode(_format, _caller_type_info, {:type, :t, 0}, _target_type, data, _config) do
    Spectral.Error.type_mismatch(@type_ref, data)
  end

  @impl Spectral.Codec
  def decode(format, _caller_type_info, {:type, :t, 0}, _target_type, input, _config)
      when format in [:json, :binary_string] and is_binary(input) do
    case Date.from_iso8601(input) do
      {:ok, d} -> {:ok, d}
      {:error, _} -> Spectral.Error.type_mismatch(@type_ref, input, :invalid_format)
    end
  end

  def decode(:string, _caller_type_info, {:type, :t, 0}, _target_type, input, _config)
      when is_list(input) do
    case Date.from_iso8601(List.to_string(input)) do
      {:ok, d} -> {:ok, d}
      {:error, _} -> Spectral.Error.type_mismatch(@type_ref, input, :invalid_format)
    end
  end

  def decode(_format, _caller_type_info, {:type, :t, 0}, _target_type, data, _config) do
    Spectral.Error.type_mismatch(@type_ref, data)
  end

  @impl Spectral.Codec
  def schema(_format, _caller_type_info, {:type, :t, 0}, _target_type, _config) do
    %{type: "string", format: "date"}
  end
end
