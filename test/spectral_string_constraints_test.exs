defmodule SpectralStringConstraintsTest do
  use ExUnit.Case, async: true

  describe "min_length / max_length enforcement" do
    test "encode accepts string within bounds" do
      assert {:ok, _} =
               Spectral.encode("hi", StringConstraintsModule, :bounded, :json, [:pre_encoded])
    end

    test "encode rejects string shorter than min_length" do
      assert {:error, [%Spectral.Error{type: :type_mismatch}]} =
               Spectral.encode("x", StringConstraintsModule, :bounded, :json, [:pre_encoded])
    end

    test "encode rejects string longer than max_length" do
      assert {:error, [%Spectral.Error{type: :type_mismatch}]} =
               Spectral.encode("toolongstring", StringConstraintsModule, :bounded, :json, [
                 :pre_encoded
               ])
    end

    test "decode accepts string within bounds" do
      assert {:ok, "hi"} =
               Spectral.decode("hi", StringConstraintsModule, :bounded, :json, [:pre_decoded])
    end

    test "decode rejects string shorter than min_length" do
      assert {:error, [%Spectral.Error{type: :type_mismatch}]} =
               Spectral.decode("x", StringConstraintsModule, :bounded, :json, [:pre_decoded])
    end

    test "decode rejects string longer than max_length" do
      assert {:error, [%Spectral.Error{type: :type_mismatch}]} =
               Spectral.decode("toolongstring", StringConstraintsModule, :bounded, :json, [
                 :pre_decoded
               ])
    end

    test "schema includes minLength and maxLength" do
      schema =
        Spectral.schema(StringConstraintsModule, :bounded, :json_schema, [:pre_encoded])

      assert schema[:minLength] == 2
      assert schema[:maxLength] == 10
    end
  end

  describe "pattern enforcement" do
    test "encode accepts string matching pattern" do
      assert {:ok, _} =
               Spectral.encode("hello", StringConstraintsModule, :lowercase, :json, [:pre_encoded])
    end

    test "encode rejects string not matching pattern" do
      assert {:error, [%Spectral.Error{type: :type_mismatch}]} =
               Spectral.encode("Hello", StringConstraintsModule, :lowercase, :json, [:pre_encoded])
    end

    test "decode accepts string matching pattern" do
      assert {:ok, "hello"} =
               Spectral.decode("hello", StringConstraintsModule, :lowercase, :json, [:pre_decoded])
    end

    test "decode rejects string not matching pattern" do
      assert {:error, [%Spectral.Error{type: :type_mismatch}]} =
               Spectral.decode("Hello", StringConstraintsModule, :lowercase, :json, [:pre_decoded])
    end

    test "schema includes pattern" do
      schema =
        Spectral.schema(StringConstraintsModule, :lowercase, :json_schema, [:pre_encoded])

      assert schema[:pattern] == "^[a-z]+$"
    end
  end

  describe "format annotation" do
    test "schema includes format" do
      schema =
        Spectral.schema(StringConstraintsModule, :annotated, :json_schema, [:pre_encoded])

      assert schema[:format] == "hostname"
    end

    test "format is not enforced at encode/decode" do
      # format is schema annotation only — any string passing other constraints is accepted
      assert {:ok, _} =
               Spectral.encode("not-a-hostname!", StringConstraintsModule, :annotated, :json, [
                 :pre_encoded
               ])
    end
  end
end
