defmodule Spectral.Codec.ISO8601 do
  @moduledoc false
  # Shared encode/decode for calendar codecs whose module exposes
  # `to_iso8601/1` and `from_iso8601/1` returning `{:ok, value} | {:error, _}`.
  #
  # `decode/4` takes the regex the codec publishes in its schema and rejects
  # input that does not match it, since `from_iso8601/1` also accepts forms
  # the schema forbids (an offset it drops, a space separator, a leading "T").

  @type_ref {:type, :t, 0}

  def encode(module, format, %{__struct__: module} = value)
      when format in [:json, :binary_string] do
    {:ok, module.to_iso8601(value)}
  end

  def encode(module, :string, %{__struct__: module} = value) do
    {:ok, String.to_charlist(module.to_iso8601(value))}
  end

  def encode(_module, _format, data), do: Spectral.Error.type_mismatch(@type_ref, data)

  def decode(module, format, input, pattern \\ nil)

  def decode(module, format, input, pattern)
      when format in [:json, :binary_string] and is_binary(input) do
    from_iso8601(module, input, input, pattern)
  end

  def decode(module, :string, input, pattern) when is_list(input) do
    from_iso8601(module, List.to_string(input), input, pattern)
  end

  def decode(_module, _format, data, _pattern), do: Spectral.Error.type_mismatch(@type_ref, data)

  defp from_iso8601(module, string, input, pattern) do
    with true <- matches?(pattern, string),
         {:ok, value} <- module.from_iso8601(string) do
      {:ok, value}
    else
      _ -> Spectral.Error.type_mismatch(@type_ref, input, :invalid_format)
    end
  end

  defp matches?(nil, _string), do: true
  defp matches?(pattern, string), do: Regex.match?(Regex.compile!(pattern), string)
end
