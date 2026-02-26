defmodule SpectralTypepTest do
  use ExUnit.Case, async: true

  test "module with undocumented @typep compiles without error" do
    type_info = TestTypepWithoutSpectral.__spectra_type_info__()
    assert {:ok, _} = Spectral.TypeInfo.find_type(type_info, :t, 0)
  end

  test "spectral on @typep stores title and description in __spectra_type_info__" do
    type_info = TestTypepWithSpectral.__spectra_type_info__()
    assert {:ok, type} = Spectral.TypeInfo.find_type(type_info, :internal_id, 0)

    assert %{doc: %{title: "Internal ID", description: "A private identifier"}} =
             :spectra_type.get_meta(type)
  end
end
