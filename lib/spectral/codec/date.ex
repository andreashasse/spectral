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

  @impl Spectral.Codec
  def encode(format, Date, {:type, :t, 0}, %Date{} = d, _sp_type, _params)
      when format in [:json, :binary_string] do
    {:ok, Date.to_iso8601(d)}
  end

  def encode(:string, Date, {:type, :t, 0}, %Date{} = d, _sp_type, _params) do
    {:ok, String.to_charlist(Date.to_iso8601(d))}
  end

  def encode(_format, Date, {:type, :t, 0}, data, _sp_type, _params) do
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
  def decode(format, Date, {:type, :t, 0}, input, _sp_type, _params)
      when format in [:json, :binary_string] and is_binary(input) do
    case Date.from_iso8601(input) do
      {:ok, d} ->
        {:ok, d}

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

  def decode(:string, Date, {:type, :t, 0}, input, _sp_type, _params) when is_list(input) do
    case Date.from_iso8601(List.to_string(input)) do
      {:ok, d} ->
        {:ok, d}

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

  def decode(_format, Date, {:type, :t, 0}, data, _sp_type, _params) do
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
  def schema(_format, Date, {:type, :t, 0}, _sp_type, _params) do
    %{type: "string", format: "date"}
  end
end
