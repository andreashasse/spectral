defmodule SpectralErrorReportingTest do
  use ExUnit.Case, async: true

  @valid %ErrorFieldsModule{id: "item_abc", kind: :small}

  describe "string constraint errors name the alias type" do
    test "pattern mismatch inside a struct" do
      assert {:error, [%Spectral.Error{location: [:id], context: context}]} =
               Spectral.encode(%{@valid | id: "item_ABC"}, ErrorFieldsModule, :t, :json, [
                 :pre_encoded
               ])

      assert %{reason: :pattern, type: {:type, :item_id, 0}} = context
    end

    test "min_length and max_length mismatches" do
      assert {:error,
              [%Spectral.Error{context: %{reason: :min_length, type: {:type, :item_id, 0}}}]} =
               Spectral.decode("item_", ErrorFieldsModule, :item_id, :json, [:pre_decoded])

      assert {:error,
              [%Spectral.Error{context: %{reason: :max_length, type: {:type, :item_id, 0}}}]} =
               Spectral.decode(String.duplicate("item_", 5), ErrorFieldsModule, :item_id, :json, [
                 :pre_decoded
               ])
    end

    test "non-binary input" do
      assert {:error, [%Spectral.Error{context: %{type: {:type, :item_id, 0}}}]} =
               Spectral.decode(12, ErrorFieldsModule, :item_id, :json, [:pre_decoded])
    end

    test "plain String.t() keeps the String.t/0 name" do
      assert {:error, [%Spectral.Error{location: [:email], context: %{type: {:type, :t, 0}}}]} =
               Spectral.decode(%{"email" => 12}, ErrorFieldsModule.Contact, :t, :json, [
                 :pre_decoded
               ])
    end
  end
end
