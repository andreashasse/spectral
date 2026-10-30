defmodule Spectral.Codec.Time do
  @moduledoc """
  Built-in codec for `Time.t()`.

  Encodes `Time` structs to ISO 8601 strings without an offset
  (e.g. `"12:30:00"`) and decodes them back. Handles `:json` and
  `:binary_string` formats (returning a binary string) and `:string` format
  (returning a charlist).

  The schema is a `string` with a `pattern`, not `format: "time"`: JSON
  Schema's `time` format is RFC 3339 `full-time`, which requires an offset,
  and a `Time` has none.

  ## Registration

  Registered automatically when the `:spectral` application starts. To use a
  different codec for `Time.t()`, set it in `config :spectra, :codecs`;
  user-configured codecs take precedence over the built-ins.
  """

  use Spectral.Codec

  alias Spectral.Codec.ISO8601

  @pattern "^\\d{2}:\\d{2}:\\d{2}(\\.\\d+)?$"

  @impl Spectral.Codec
  def encode(format, _caller_type_info, {:type, :t, 0}, _target_type, data, _config) do
    ISO8601.encode(Time, format, data)
  end

  @impl Spectral.Codec
  def decode(format, _caller_type_info, {:type, :t, 0}, _target_type, input, _config) do
    ISO8601.decode(Time, format, input, @pattern)
  end

  @impl Spectral.Codec
  def schema(_format, _caller_type_info, {:type, :t, 0}, _target_type, _config) do
    %{type: "string", pattern: @pattern}
  end
end
