defmodule SpectralCodecHelpersTest do
  @moduledoc """
  Covers two things a codec author has no way to discover from the outside: that the
  recursive helpers accept a type *reference*, and that `schema/5` may decline a type.
  """
  use ExUnit.Case, async: true

  describe "recursive helpers accept a type reference" do
    # `Spectral.sp_type_or_ref()` includes `{:type, name, arity}`, so a codec may pass one
    # instead of a resolved node from `Spectral.Type.type_args/1`.

    test "decode/5 resolves the reference against the given type_info" do
      assert {:ok, %CodecRefModule.Inner{name: "Alice"}} =
               Spectral.decode(%{"name" => "Alice"}, CodecRefModule, :outer, :json, [
                 :pre_decoded
               ])
    end

    test "encode/5 resolves the reference against the given type_info" do
      assert {:ok, %{"name" => "Alice"}} =
               Spectral.encode(
                 %CodecRefModule.Inner{name: "Alice"},
                 CodecRefModule,
                 :outer,
                 :json,
                 [
                   :pre_encoded
                 ]
               )
    end

    test "schema/4 resolves the reference against the given type_info" do
      assert %{type: "object", properties: %{"name" => %{type: "string"}}} =
               Spectral.schema(CodecRefModule, :outer, :json_schema, [:pre_encoded])
    end

    test "schema/4 also resolves a {:record, name} reference" do
      assert %{type: "object"} =
               Spectral.schema(CodecRefModule, :record_ref, :json_schema, [:pre_encoded])
    end

    test "errors from the resolved type still surface" do
      assert {:error, [%Spectral.Error{} | _]} =
               Spectral.decode(%{"name" => 42}, CodecRefModule, :outer, :json, [:pre_decoded])
    end
  end

  describe "schema/5 may decline a type" do
    # Once `schema/5` is implemented it receives every type in the codec module, including
    # the ones the codec does not own.

    test "a :continue return falls through to the structural schema" do
      assert %{type: "integer"} =
               Spectral.schema(CodecRefModule, :plain, :json_schema, [:pre_encoded])
    end

    test "the declined type still encodes and decodes structurally" do
      assert {:ok, 42} = Spectral.decode(42, CodecRefModule, :plain, :json, [:pre_decoded])
      assert {:ok, 42} = Spectral.encode(42, CodecRefModule, :plain, :json, [:pre_encoded])
    end
  end
end
