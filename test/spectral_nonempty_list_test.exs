defmodule SpectralNonemptyListTest do
  use ExUnit.Case, async: true

  describe "[elem, ...] shorthand" do
    test "encode/decode round-trips a non-empty list" do
      data = %{tags: ["a", "b"]}

      assert {:ok, encoded} =
               Spectral.encode(data, NonemptyListModule, :shorthand, :json, [:pre_encoded])

      assert {:ok, ^data} =
               Spectral.decode(encoded, NonemptyListModule, :shorthand, :json, [:pre_decoded])
    end

    test "encode rejects an empty list" do
      assert {:error, [%Spectral.Error{}]} =
               Spectral.encode(%{tags: []}, NonemptyListModule, :shorthand, :json, [:pre_encoded])
    end

    test "decode rejects an empty list" do
      assert {:error, [%Spectral.Error{}]} =
               Spectral.decode(%{"tags" => []}, NonemptyListModule, :shorthand, :json, [
                 :pre_decoded
               ])
    end

    test "schema has minItems 1, matching nonempty_list(elem)" do
      shorthand = Spectral.schema(NonemptyListModule, :shorthand, :json_schema, [:pre_encoded])
      longhand = Spectral.schema(NonemptyListModule, :longhand, :json_schema, [:pre_encoded])

      assert shorthand[:properties]["tags"][:minItems] == 1
      assert shorthand == longhand
    end
  end
end
