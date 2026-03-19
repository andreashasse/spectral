defmodule SpectralCodecErlangStyleTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Verifies that errors from an Erlang-style codec (returning raw sp_error records
  rather than %Spectral.Error{} structs) are properly converted to %Spectral.Error{}
  when surfaced through Spectral.encode/decode.
  """

  test "encode errors from erlang-style codec are converted to %Spectral.Error{}" do
    {:error, [error]} = Spectral.encode(123, ErlangStyleCodec, :t)
    assert %Spectral.Error{type: :type_mismatch} = error
  end

  test "decode errors from erlang-style codec are converted to %Spectral.Error{}" do
    {:error, [error]} = Spectral.decode(123, ErlangStyleCodec, :t)
    assert %Spectral.Error{type: :type_mismatch} = error
  end
end
