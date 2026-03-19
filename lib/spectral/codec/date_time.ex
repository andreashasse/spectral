defmodule Spectral.Codec.DateTime do
  @moduledoc """
  Built-in codec for `DateTime.t()`.

  Encodes `DateTime` structs to ISO 8601 / RFC 3339 strings
  (e.g. `"2012-04-23T18:25:43.511Z"`) and decodes them back.
  Handles `:json` and `:binary` formats (returning a binary string) and
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
  def encode(format, DateTime, {:type, :t, 0}, %DateTime{} = dt, _params)
      when format in [:json, :binary] do
    {:ok, DateTime.to_iso8601(dt)}
  end

  def encode(:string, DateTime, {:type, :t, 0}, %DateTime{} = dt, _params) do
    {:ok, String.to_charlist(DateTime.to_iso8601(dt))}
  end

  def encode(_format, DateTime, {:type, :t, 0}, data, _params) do
    {:error, [type_mismatch({:type, :t, 0}, data)]}
  end

  @impl Spectral.Codec
  def decode(format, DateTime, {:type, :t, 0}, input, _params)
      when format in [:json, :binary] and is_binary(input) do
    case DateTime.from_iso8601(input) do
      {:ok, dt, _offset} ->
        {:ok, dt}

      {:error, _} ->
        {:error, [type_mismatch({:type, :t, 0}, input, %{reason: :invalid_format})]}
    end
  end

  def decode(:string, DateTime, {:type, :t, 0}, input, _params) when is_list(input) do
    case DateTime.from_iso8601(List.to_string(input)) do
      {:ok, dt, _offset} ->
        {:ok, dt}

      {:error, _} ->
        {:error, [type_mismatch({:type, :t, 0}, input, %{reason: :invalid_format})]}
    end
  end

  def decode(_format, DateTime, {:type, :t, 0}, data, _params) do
    {:error, [type_mismatch({:type, :t, 0}, data)]}
  end

  @impl Spectral.Codec
  def schema(_format, DateTime, {:type, :t, 0}, _params) do
    %{type: "string", format: "date-time"}
  end
end
