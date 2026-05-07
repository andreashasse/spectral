defmodule SpectralRefPropagationTest do
  # Tests for field_aliases and only propagation through type references (spectra 0.13.1).
  # These transforms were silently dropped at reference boundaries in 0.13.0.
  use ExUnit.Case, async: true

  describe "field_aliases on remote type reference" do
    test "encode uses aliased keys when field_aliases is declared on a remote type ref" do
      data = %TypeRefModule.Inner{first_name: "Alice", last_name: "Smith", secret: "x"}
      {:ok, json_io} = Spectral.encode(data, TypeRefModule, :aliased_t)
      decoded = json_io |> IO.iodata_to_binary() |> Jason.decode!()
      assert %{"firstName" => "Alice", "lastName" => "Smith"} = decoded
      refute Map.has_key?(decoded, "first_name")
      refute Map.has_key?(decoded, "last_name")
    end

    test "decode accepts aliased keys when field_aliases is declared on a remote type ref" do
      json = ~s({"firstName":"Bob","lastName":"Jones","secret":"y"})
      {:ok, result} = Spectral.decode(json, TypeRefModule, :aliased_t)
      assert %{first_name: "Bob", last_name: "Jones"} = result
    end
  end

  describe "only on remote type reference" do
    test "only filters fields when declared on a remote type ref" do
      data = %TypeRefModule.Inner{first_name: "Alice", last_name: "Smith", secret: "classified"}
      {:ok, json_io} = Spectral.encode(data, TypeRefModule, :restricted_t)
      decoded = json_io |> IO.iodata_to_binary() |> Jason.decode!()
      assert %{"first_name" => _, "last_name" => _} = decoded
      refute Map.has_key?(decoded, "secret")
    end
  end

  describe "only + field_aliases on remote type reference" do
    test "only and field_aliases compose when declared on a remote type ref" do
      data = %TypeRefModule.Inner{first_name: "Alice", last_name: "Smith", secret: "classified"}
      {:ok, json_io} = Spectral.encode(data, TypeRefModule, :restricted_aliased_t)
      decoded = json_io |> IO.iodata_to_binary() |> Jason.decode!()
      assert %{"firstName" => "Alice", "last_name" => _} = decoded
      refute Map.has_key?(decoded, "first_name")
      refute Map.has_key?(decoded, "secret")
    end
  end
end
