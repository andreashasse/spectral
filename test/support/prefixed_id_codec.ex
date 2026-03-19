defmodule PrefixedIdCodec do
  @moduledoc false

  use Spectral.Codec
  use Spectral

  spectral(type_parameters: "user:")
  @type user_id :: String.t()

  spectral(type_parameters: "org:")
  @type org_id :: String.t()

  @impl Spectral.Codec
  def encode(_format, PrefixedIdCodec, {:type, type, 0}, id, prefix)
      when type in [:user_id, :org_id] and is_binary(id) and is_binary(prefix) do
    {:ok, prefix <> id}
  end

  def encode(_format, PrefixedIdCodec, {:type, type, 0}, data, _prefix)
      when type in [:user_id, :org_id] do
    {:error, [type_mismatch({:type, type, 0}, data)]}
  end

  def encode(_format, _module, _type_ref, _data, _params), do: :continue

  @impl Spectral.Codec
  def decode(_format, PrefixedIdCodec, {:type, type, 0}, encoded, prefix)
      when type in [:user_id, :org_id] and is_binary(encoded) and is_binary(prefix) do
    prefix_len = byte_size(prefix)

    case encoded do
      <<^prefix::binary-size(prefix_len), id::binary>> -> {:ok, id}
      _ -> {:error, [type_mismatch({:type, type, 0}, encoded)]}
    end
  end

  def decode(_format, _module, _type_ref, _input, _params), do: :continue

  @impl Spectral.Codec
  def schema(_format, PrefixedIdCodec, {:type, type, 0}, prefix)
      when type in [:user_id, :org_id] do
    %{type: "string", pattern: "^" <> prefix}
  end
end
