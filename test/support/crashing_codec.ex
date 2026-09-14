defmodule CrashingCodec do
  @moduledoc """
  A codec whose callbacks crash with a normal Elixir exception instead of
  returning `:continue` or `{:error, _}`. Used to verify that an unexpected
  crash from inside spectra surfaces to the caller unchanged, rather than
  being turned into a misleading error about Spectral itself.
  """

  use Spectral.Codec

  @type t :: String.t()

  @impl Spectral.Codec
  def encode(_format, _caller_type_info, {:type, :t, 0}, _target_type, _data, _config) do
    Map.fetch!(Map.new(), :missing_key)
  end

  def encode(_format, _caller_type_info, _type_ref, _target_type, _data, _config), do: :continue

  @impl Spectral.Codec
  def decode(_format, _caller_type_info, {:type, :t, 0}, _target_type, _input, _config) do
    Map.fetch!(Map.new(), :missing_key)
  end

  def decode(_format, _caller_type_info, _type_ref, _target_type, _input, _config), do: :continue
end
