defmodule Spectral.Codec.NaiveDateTime do
  @moduledoc """
  Built-in codec for `NaiveDateTime.t()`.

  Encodes `NaiveDateTime` structs to ISO 8601 strings without an offset
  (e.g. `"2023-04-01T12:30:00"`) and decodes them back. Handles `:json` and
  `:binary_string` formats (returning a binary string) and `:string` format
  (returning a charlist).

  The schema is a `string` with a `pattern`, not `format: "date-time"`: JSON
  Schema's `date-time` format requires an offset, which a `NaiveDateTime` lacks.

  ## Registration

  Registered automatically when the `:spectral` application starts. To use a
  different codec for `NaiveDateTime.t()`, set it in `config :spectra, :codecs`;
  user-configured codecs take precedence over the built-ins.
  """

  use Spectral.Codec

  alias Spectral.Codec.ISO8601

  @pattern "^-?\\d{4,}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\.\\d+)?$"

  @impl Spectral.Codec
  def encode(format, _caller_type_info, {:type, :t, 0}, _target_type, data, _config) do
    ISO8601.encode(NaiveDateTime, format, data)
  end

  @impl Spectral.Codec
  def decode(format, _caller_type_info, {:type, :t, 0}, _target_type, input, _config) do
    ISO8601.decode(NaiveDateTime, format, input)
  end

  @impl Spectral.Codec
  def schema(_format, _caller_type_info, {:type, :t, 0}, _target_type, _config) do
    %{type: "string", pattern: @pattern}
  end
end
