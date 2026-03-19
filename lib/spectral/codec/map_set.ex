defmodule Spectral.Codec.MapSet do
  @moduledoc """
  Built-in codec for `MapSet.t()` and `MapSet.t(elem)`.

  Encodes `MapSet` structs to JSON arrays and decodes lists back to `MapSet`.
  The resulting JSON array reflects the unordered nature of sets — duplicate
  entries that may exist in the decoded list are collapsed.

  ## Registration

  Register this codec in your application's `config/config.exs` or
  `application.ex` start callback before encoding/decoding `MapSet` values:

      Application.put_env(:spectra, :codecs, %{
        {MapSet, {:type, :t, 0}} => Spectral.Codec.MapSet,
        {MapSet, {:type, :t, 1}} => Spectral.Codec.MapSet
      })
  """

  use Spectral.Codec

  @impl Spectral.Codec
  def encode(_format, MapSet, type_ref, %MapSet{} = ms, _params)
      when type_ref in [{:type, :t, 0}, {:type, :t, 1}] do
    {:ok, MapSet.to_list(ms)}
  end

  def encode(_format, MapSet, type_ref, data, _params)
      when type_ref in [{:type, :t, 0}, {:type, :t, 1}] do
    {:error, [type_mismatch(type_ref, data)]}
  end

  @impl Spectral.Codec
  def decode(_format, MapSet, type_ref, input, _params)
      when type_ref in [{:type, :t, 0}, {:type, :t, 1}] and is_list(input) do
    {:ok, MapSet.new(input)}
  end

  def decode(_format, MapSet, type_ref, input, _params)
      when type_ref in [{:type, :t, 0}, {:type, :t, 1}] do
    {:error, [type_mismatch(type_ref, input)]}
  end

  @impl Spectral.Codec
  def schema(_format, MapSet, type_ref, _params)
      when type_ref in [{:type, :t, 0}, {:type, :t, 1}] do
    %{type: "array", uniqueItems: true}
  end
end
