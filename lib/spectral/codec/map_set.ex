defmodule Spectral.Codec.MapSet do
  @moduledoc """
  Built-in codec for `MapSet.t()` and `MapSet.t(elem)`.

  Encodes `MapSet` structs to JSON arrays and decodes JSON arrays back to `MapSet`.
  The resulting JSON array reflects the unordered nature of sets — duplicate
  entries that may appear in the decoded list are collapsed.

  For `MapSet.t(elem)`, each element is recursively encoded/decoded according to
  its type. For `MapSet.t()`, elements are passed through as-is.

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
  def encode(:json, _mod, {:type, :t, 0}, %MapSet{} = ms, _sp_type, _params) do
    {:ok, MapSet.to_list(ms)}
  end

  def encode(:json, mod, {:type, :t, 1}, %MapSet{} = ms, sp_type, _params) do
    case Spectral.Type.type_args(sp_type) do
      [elem_type] -> encode_elements(MapSet.to_list(ms), mod, elem_type)
      [] -> {:ok, MapSet.to_list(ms)}
    end
  end

  def encode(_format, _mod, type_ref, data, _sp_type, _params)
      when type_ref in [{:type, :t, 0}, {:type, :t, 1}] do
    {:error,
     [
       %Spectral.Error{
         type: :type_mismatch,
         location: [],
         context: %{type: type_ref, value: data}
       }
     ]}
  end

  @impl Spectral.Codec
  def decode(:json, _mod, {:type, :t, 0}, input, _sp_type, _params) when is_list(input) do
    {:ok, MapSet.new(input)}
  end

  def decode(:json, mod, {:type, :t, 1}, input, sp_type, _params) when is_list(input) do
    case Spectral.Type.type_args(sp_type) do
      [elem_type] -> decode_elements(input, mod, elem_type)
      [] -> {:ok, MapSet.new(input)}
    end
  end

  def decode(_format, _mod, type_ref, input, _sp_type, _params)
      when type_ref in [{:type, :t, 0}, {:type, :t, 1}] do
    {:error,
     [
       %Spectral.Error{
         type: :type_mismatch,
         location: [],
         context: %{type: type_ref, value: input}
       }
     ]}
  end

  @impl Spectral.Codec
  def schema(:json_schema, _mod, {:type, :t, 0}, _sp_type, _params) do
    %{type: "array", uniqueItems: true}
  end

  def schema(:json_schema, mod, {:type, :t, 1}, sp_type, _params) do
    case Spectral.Type.type_args(sp_type) do
      [elem_type] ->
        %{
          type: "array",
          uniqueItems: true,
          items: Spectral.schema(mod, elem_type, :json_schema, [:pre_encoded])
        }

      [] ->
        %{type: "array", uniqueItems: true}
    end
  end

  defp encode_elements(elems, mod, elem_type) do
    result =
      Enum.reduce_while(elems, [], fn elem, acc ->
        case Spectral.encode(elem, mod, elem_type, :json, [:pre_encoded]) do
          {:ok, encoded} -> {:cont, [encoded | acc]}
          {:error, _} = err -> {:halt, err}
        end
      end)

    case result do
      {:error, _} = err -> err
      list -> {:ok, list}
    end
  end

  defp decode_elements(elems, mod, elem_type) do
    result =
      Enum.reduce_while(elems, [], fn elem, acc ->
        case Spectral.decode(elem, mod, elem_type, :json, [:pre_decoded]) do
          {:ok, decoded} -> {:cont, [decoded | acc]}
          {:error, _} = err -> {:halt, err}
        end
      end)

    case result do
      {:error, _} = err -> err
      list -> {:ok, MapSet.new(list)}
    end
  end
end
