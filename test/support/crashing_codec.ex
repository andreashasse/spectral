defmodule CrashingCodec do
  @moduledoc """
  A codec whose callbacks crash instead of returning `:continue` or
  `{:error, _}`. Used to verify that an unexpected crash from inside spectra
  surfaces to the caller unchanged, rather than being turned into a
  misleading error about Spectral itself.

  `t` crashes with a normal Elixir exception (`%KeyError{}`) to exercise the
  fallback for exceptions that are not `%ErlangError{}` at all. `t2` crashes
  with a raw BEAM error Elixir has no specific exception for, producing a
  genuine `%ErlangError{}` with an unrecognized `original`, to exercise the
  other fallback (an `%ErlangError{}` that isn't one of the known
  configuration errors).
  """

  use Spectral.Codec

  @type t :: String.t()
  @type t2 :: String.t()

  @impl Spectral.Codec
  def encode(_format, _caller_type_info, {:type, :t, 0}, _target_type, _data, _config) do
    Map.fetch!(Map.new(), :missing_key)
  end

  def encode(_format, _caller_type_info, {:type, :t2, 0}, _target_type, _data, _config) do
    :erlang.error({:unexpected_codec_failure, :detail})
  end

  def encode(_format, _caller_type_info, _type_ref, _target_type, _data, _config), do: :continue

  @impl Spectral.Codec
  def decode(_format, _caller_type_info, {:type, :t, 0}, _target_type, _input, _config) do
    Map.fetch!(Map.new(), :missing_key)
  end

  def decode(_format, _caller_type_info, _type_ref, _target_type, _input, _config), do: :continue

  @impl Spectral.Codec
  def schema(_format, _caller_type_info, {:type, :t, 0}, _target_type, _config) do
    Map.fetch!(Map.new(), :missing_key)
  end
end
