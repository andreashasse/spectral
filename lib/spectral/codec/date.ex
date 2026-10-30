defmodule Spectral.Codec.Date do
  @moduledoc """
  Built-in codec for `Date.t()`.

  Encodes `Date` structs to ISO 8601 strings (e.g. `"2023-04-01"`) and decodes
  them back. Handles `:json` and `:binary_string` formats (returning a binary string)
  and `:string` format (returning a charlist).

  ## Registration

  Registered automatically when the `:spectral` application starts. To use a
  different codec for `Date.t()`, set it in `config :spectra, :codecs`;
  user-configured codecs take precedence over the built-ins.
  """

  use Spectral.Codec

  alias Spectral.Codec.ISO8601

  @impl Spectral.Codec
  def encode(format, _caller_type_info, {:type, :t, 0}, _target_type, data, _config) do
    ISO8601.encode(Date, format, data)
  end

  @impl Spectral.Codec
  def decode(format, _caller_type_info, {:type, :t, 0}, _target_type, input, _config) do
    ISO8601.decode(Date, format, input)
  end

  @impl Spectral.Codec
  def schema(_format, _caller_type_info, {:type, :t, 0}, _target_type, _config) do
    %{type: "string", format: "date"}
  end
end
