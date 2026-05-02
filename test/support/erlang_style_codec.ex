defmodule ErlangStyleCodec do
  @moduledoc """
  Simulates an Erlang-implemented codec: uses @behaviour directly (no `use Spectral.Codec`)
  and returns raw sp_error records rather than %Spectral.Error{} structs.
  """

  @behaviour Spectral.Codec

  @type t :: String.t()

  @impl Spectral.Codec
  def encode(_format, _caller_type_info, {:type, :t, 0}, _target_type, data, _config)
      when is_binary(data) do
    {:ok, data}
  end

  def encode(_format, _caller_type_info, {:type, :t, 0}, _target_type, data, _config) do
    {:error, [:sp_error.type_mismatch({:type, :t, 0}, data)]}
  end

  def encode(_format, _caller_type_info, _type_ref, _target_type, _data, _config), do: :continue

  @impl Spectral.Codec
  def decode(_format, _caller_type_info, {:type, :t, 0}, _target_type, input, _config)
      when is_binary(input) do
    {:ok, input}
  end

  def decode(_format, _caller_type_info, {:type, :t, 0}, _target_type, input, _config) do
    {:error, [:sp_error.type_mismatch({:type, :t, 0}, input)]}
  end

  def decode(_format, _caller_type_info, _type_ref, _target_type, _input, _config), do: :continue
end
