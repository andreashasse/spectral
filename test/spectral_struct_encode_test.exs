defmodule SpectralStructEncodeTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Encoding a struct type with data that isn't a map (a string, integer, list,
  or atom) crashed with a raw `badmap` error instead of returning
  `{:error, [%Spectral.Error{}]}`, because the struct branch of spectra's
  encoder was missing the `is_map/1` guard the plain map, list, and record
  branches already had. Fixed in spectra 0.14.1.
  """

  test "encoding non-map data against a struct type returns a type_mismatch error" do
    assert {:error, [%Spectral.Error{type: :type_mismatch}]} =
             Spectral.encode("not a map", Person, {:type, :t, 0})
  end

  test "encoding! raises Spectral.Error rather than crashing" do
    assert_raise Spectral.Error, fn ->
      Spectral.encode!("not a map", Person, {:type, :t, 0})
    end
  end
end
