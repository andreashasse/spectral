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
  def encode(:json, _caller_type_info, {:type, :t, 0}, _target_type, %MapSet{} = ms, _config) do
    {:ok, MapSet.to_list(ms)}
  end

  def encode(:json, caller_type_info, {:type, :t, 1}, target_type, %MapSet{} = ms, config) do
    case Spectral.Type.type_args(target_type) do
      [elem_type] -> encode_elements(MapSet.to_list(ms), caller_type_info, elem_type, config)
      [] -> {:ok, MapSet.to_list(ms)}
    end
  end

  def encode(_format, _caller_type_info, type_ref, _target_type, data, _config)
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
  def decode(:json, _caller_type_info, {:type, :t, 0}, _target_type, input, _config)
      when is_list(input) do
    {:ok, MapSet.new(input)}
  end

  def decode(:json, caller_type_info, {:type, :t, 1}, target_type, input, config)
      when is_list(input) do
    case Spectral.Type.type_args(target_type) do
      [elem_type] -> decode_elements(input, caller_type_info, elem_type, config)
      [] -> {:ok, MapSet.new(input)}
    end
  end

  def decode(_format, _caller_type_info, type_ref, _target_type, input, _config)
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
  def schema(:json_schema, _caller_type_info, {:type, :t, 0}, _target_type, _config) do
    %{type: "array", uniqueItems: true}
  end

  def schema(:json_schema, caller_type_info, {:type, :t, 1}, target_type, config) do
    case Spectral.Type.type_args(target_type) do
      [elem_type] ->
        %{
          type: "array",
          uniqueItems: true,
          items: Spectral.Codec.schema(caller_type_info, elem_type, config)
        }

      [] ->
        %{type: "array", uniqueItems: true}
    end
  end

  defp encode_elements(elems, caller_type_info, elem_type, config) do
    result =
      Enum.reduce_while(elems, [], fn elem, acc ->
        case Spectral.Codec.encode(caller_type_info, elem_type, elem, config) do
          {:ok, encoded} -> {:cont, [encoded | acc]}
          {:error, _} = err -> {:halt, err}
        end
      end)

    case result do
      {:error, _} = err -> err
      list -> {:ok, list}
    end
  end

  defp decode_elements(elems, caller_type_info, elem_type, config) do
    result =
      Enum.reduce_while(elems, [], fn elem, acc ->
        case Spectral.Codec.decode(caller_type_info, elem_type, elem, config) do
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
