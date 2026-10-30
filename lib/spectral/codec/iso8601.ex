defmodule Spectral.Codec.ISO8601 do
  @moduledoc false
  # Shared encode/decode for calendar codecs whose module exposes
  # `to_iso8601/1` and `from_iso8601/1` returning `{:ok, value} | {:error, _}`.

  @type_ref {:type, :t, 0}

  def encode(module, format, %{__struct__: module} = value)
      when format in [:json, :binary_string] do
    {:ok, module.to_iso8601(value)}
  end

  def encode(module, :string, %{__struct__: module} = value) do
    {:ok, String.to_charlist(module.to_iso8601(value))}
  end

  def encode(_module, _format, data), do: Spectral.Error.type_mismatch(@type_ref, data)

  def decode(module, format, input) when format in [:json, :binary_string] and is_binary(input) do
    from_iso8601(module, input, input)
  end

  def decode(module, :string, input) when is_list(input) do
    from_iso8601(module, List.to_string(input), input)
  end

  def decode(_module, _format, data), do: Spectral.Error.type_mismatch(@type_ref, data)

  defp from_iso8601(module, string, input) do
    case module.from_iso8601(string) do
      {:ok, value} -> {:ok, value}
      {:error, _} -> Spectral.Error.type_mismatch(@type_ref, input, :invalid_format)
    end
  end
end
