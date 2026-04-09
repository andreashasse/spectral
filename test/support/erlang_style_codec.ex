defmodule ErlangStyleCodec do
  @moduledoc """
  Simulates an Erlang-implemented codec: uses @behaviour directly (no `use Spectral.Codec`)
  and returns raw sp_error records rather than %Spectral.Error{} structs.
  """

  @behaviour Spectral.Codec

  @type t :: String.t()

  @impl Spectral.Codec
  def encode(_format, ErlangStyleCodec, {:type, :t, 0}, data, _sp_type, _params, _config)
      when is_binary(data) do
    {:ok, data}
  end

  def encode(_format, ErlangStyleCodec, {:type, :t, 0}, data, _sp_type, _params, _config) do
    {:error, [:sp_error.type_mismatch({:type, :t, 0}, data)]}
  end

  def encode(_format, _module, _type_ref, _data, _sp_type, _params, _config), do: :continue

  @impl Spectral.Codec
  def decode(_format, ErlangStyleCodec, {:type, :t, 0}, input, _sp_type, _params, _config)
      when is_binary(input) do
    {:ok, input}
  end

  def decode(_format, ErlangStyleCodec, {:type, :t, 0}, input, _sp_type, _params, _config) do
    {:error, [:sp_error.type_mismatch({:type, :t, 0}, input)]}
  end

  def decode(_format, _module, _type_ref, _input, _sp_type, _params, _config), do: :continue
end
