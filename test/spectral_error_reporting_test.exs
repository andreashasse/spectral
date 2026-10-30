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

  describe "error values are hidden from inspect" do
    @email "person@example.com"

    test "a wrong struct does not leak its fields" do
      contact = %ErrorFieldsModule.Contact{email: @email}

      assert {:error, [error]} = Spectral.encode(contact, ErrorFieldsModule, :t, :json)

      assert error.context.value == contact
      refute inspect(error) =~ @email
      assert inspect(error) =~ "redacted"
      assert inspect(error) =~ "Spectral.Error"
      refute Exception.message(error) =~ @email
    end

    test "nested union errors do not leak the value" do
      value = %{@valid | kind: %ErrorFieldsModule.Contact{email: @email}}

      assert {:error, [%Spectral.Error{type: :no_match, location: [:kind]} = error]} =
               Spectral.encode(value, ErrorFieldsModule, :t, :json)

      assert [_ | _] = error.context.errors
      refute inspect(error) =~ @email
      refute inspect({:error, [error]}, pretty: true, limit: :infinity) =~ @email
      refute Exception.message(error) =~ @email
    end

    test "a raised error does not leak the value" do
      exception =
        assert_raise Spectral.Error, fn ->
          Spectral.encode!(%ErrorFieldsModule.Contact{email: @email}, ErrorFieldsModule, :t)
        end

      refute inspect(exception) =~ @email
      refute Exception.message(exception) =~ @email
    end

    test "errors without a map context still inspect" do
      assert inspect(%Spectral.Error{type: :decode_error, location: [], context: nil}) =~
               "decode_error"
    end
  end

  describe "message hints in the context" do
    test "Exception.message includes context.message" do
      error = %Spectral.Error{
        type: :not_matched_fields,
        location: [:tags],
        context: %{value: %{}, message: "map must have at least one entry"}
      }

      assert Exception.message(error) ==
               "not_matched_fields at tags: map must have at least one entry"

      assert Spectral.Error.exception(error).message == Exception.message(error)
    end

    test "a charlist message from spectra is included" do
      error = %Spectral.Error{
        type: :type_mismatch,
        location: [:name],
        context: %{value: <<255>>, message: ~c"unicode conversion failed"}
      }

      assert Exception.message(error) == "type_mismatch at name: unicode conversion failed"
    end

    test "Exception.message is unchanged without a context message" do
      error = %Spectral.Error{type: :type_mismatch, location: [], context: %{value: 1}}
      assert Exception.message(error) == "type_mismatch at root"
    end
  end
end
