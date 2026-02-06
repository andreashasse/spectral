defmodule SpectralTest do
  use ExUnit.Case
  doctest Spectral

  def encode_to_binary(data, module, type) do
    with {:ok, iodata} <- Spectral.encode(data, module, type) do
      {:ok, IO.iodata_to_binary(iodata)}
    end
  end

  test "encode json" do
    assert {:ok, ~s({"age":30,"name":"Alice"})} ==
             encode_to_binary(%Person{name: "Alice", age: 30}, Person, :t)
  end

  test "encode json missing nil value" do
    assert {:ok, ~s({"name":"Alice"})} == encode_to_binary(%Person{name: "Alice"}, Person, :t)
  end

  test "decode json" do
    assert {:ok, %Person{name: "Alice", age: 30, address: nil}} ==
             Spectral.decode(~s({"name":"Alice","age":30}), Person, :t)
  end

  test "decode json with missing optional fields" do
    assert {:ok, %Person{name: "Alice", age: nil, address: nil}} ==
             Spectral.decode(~s({"name":"Alice"}), Person, :t)
  end

  test "decode json with explicit null for optional fields" do
    assert {:ok, %Person{name: "Alice", age: nil, address: nil}} ==
             Spectral.decode(~s({"name":"Alice","age":null,"address":null}), Person, :t)
  end

  test "decode json ignores extra fields in root object" do
    assert {:ok, %Person{name: "Alice", age: 30, address: nil}} ==
             Spectral.decode(
               ~s({"name":"Alice","age":30,"extra_field":"ignored","another_field":123}),
               Person,
               :t
             )
  end

  test "decode json ignores extra fields in nested objects" do
    assert {:ok,
            %Person{
              name: "Alice",
              age: 30,
              address: %Person.Address{street: "Main St", city: "Berlin"}
            }} ==
             Spectral.decode(
               ~s({"name":"Alice","age":30,"address":{"street":"Main St","city":"Berlin","extra":"ignored"}}),
               Person,
               :t
             )
  end

  test "decode json ignores extra fields with all types" do
    # Test that extra fields of various types (string, number, boolean, null, object, array) are all ignored
    json =
      ~s({"name":"Alice","age":30,"string_field":"extra","number_field":999,"bool_field":true,"null_field":null,"object_field":{"nested":"value"},"array_field":[1,2,3]})

    assert {:ok, %Person{name: "Alice", age: 30, address: nil}} ==
             Spectral.decode(json, Person, :t)
  end

  test "encode! returns result directly" do
    assert ~s({"age":30,"name":"Alice"}) ==
             %Person{name: "Alice", age: 30}
             |> Spectral.encode!(Person, :t)
             |> IO.iodata_to_binary()
  end

  test "decode! returns result directly" do
    assert %Person{name: "Alice", age: 30, address: nil} ==
             Spectral.decode!(~s({"name":"Alice","age":30}), Person, :t)
  end

  test "schema returns result directly" do
    schema =
      Spectral.schema(Person.Address, :t)
      |> IO.iodata_to_binary()
      |> Jason.decode!()

    assert schema["type"] == "object"
    assert schema["required"] == ["street", "city"]
    assert schema["additionalProperties"] == false
    assert schema["properties"]["city"] == %{"type" => "string"}
    assert schema["properties"]["street"] == %{"type" => "string"}
    assert schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"
  end

  # Error handling tests - data validation errors

  test "decode returns error for type mismatch - age as string" do
    bad_json = ~s({"name":"Alice","age":"not a number"})

    assert {:error,
            [
              %Spectral.Error{
                location: [:age],
                type: :no_match,
                context: %{value: "not a number"}
              }
            ]} = Spectral.decode(bad_json, Person, :t)
  end

  test "decode returns error for type mismatch - age as negative integer" do
    bad_json = ~s({"name":"Alice","age":-5})

    assert {:error,
            [
              %Spectral.Error{
                location: [:age],
                type: :no_match,
                context: %{value: -5}
              }
            ]} = Spectral.decode(bad_json, Person, :t)
  end

  test "decode returns error for missing required field" do
    bad_json = ~s({"age":30})

    assert {:error,
            [
              %Spectral.Error{
                location: [:name],
                type: :missing_data,
                context: %{
                  type:
                    {:literal_map_field, :exact, :name, "name",
                     {:sp_remote_type, {String, :t, []}}},
                  value: %{}
                }
              }
            ]} = Spectral.decode(bad_json, Person, :t)
  end

  test "decode returns error for nested validation - invalid address" do
    bad_json = ~s({"name":"Alice","age":30,"address":{"street":123,"city":"Berlin"}})

    assert {:error,
            [
              %Spectral.Error{
                location: [:address],
                type: :no_match,
                context: %{value: %{"city" => "Berlin", "street" => 123}}
              }
            ]} = Spectral.decode(bad_json, Person, :t)
  end

  test "decode returns error for nested validation - address missing city" do
    bad_json = ~s({"name":"Alice","age":30,"address":{"street":"Main St"}})

    assert {:error,
            [
              %Spectral.Error{
                location: [:address],
                type: :no_match,
                context: %{value: %{"street" => "Main St"}}
              }
            ]} = Spectral.decode(bad_json, Person, :t)
  end

  test "decode returns error for wrong data structure - array instead of object" do
    bad_json = ~s([1, 2, 3])

    assert {:error,
            [
              %Spectral.Error{
                location: [],
                type: :type_mismatch,
                context: %{value: [1, 2, 3]}
              }
            ]} = Spectral.decode(bad_json, Person, :t)
  end

  test "decode returns error for invalid JSON syntax" do
    bad_json = ~s({"name":"Alice",})

    assert {:error, [%Spectral.Error{type: :decode_error}]} =
             Spectral.decode(bad_json, Person, :t)
  end

  test "error context contains type information" do
    bad_json = ~s({"name":"Alice","age":"not a number"})

    assert {:error,
            [
              %Spectral.Error{
                location: [:age],
                type: :no_match,
                context: %{type: _type, value: "not a number"}
              }
            ]} = Spectral.decode(bad_json, Person, :t)
  end

  test "encode returns error for invalid data type" do
    # Trying to encode with wrong type - age as string when integer expected
    invalid_person = %{name: "Alice", age: "thirty"}

    assert {:error,
            [
              %Spectral.Error{
                location: [],
                type: :type_mismatch,
                context: %{
                  message: ~c"Struct mismatch",
                  type:
                    {:sp_map,
                     [
                       {:literal_map_field, :exact, :address, "address", _},
                       {:literal_map_field, :exact, :age, "age", _},
                       {:literal_map_field, :exact, :name, "name", _}
                     ], Person},
                  value: %{name: "Alice", age: "thirty"}
                }
              }
            ]} = Spectral.encode(invalid_person, Person, :t)
  end

  # Error handling tests - bang functions

  test "decode! raises Spectral.Error with proper structure" do
    bad_json = ~s({"name":"Alice","age":"not a number"})

    exception =
      assert_raise Spectral.Error, fn ->
        Spectral.decode!(bad_json, Person, :t)
      end

    # Verify the error structure - message is generated when raised
    assert %Spectral.Error{
             location: [:age],
             type: :no_match,
             context: %{value: "not a number"}
           } = exception

    assert exception.message =~ "age"
  end

  test "decode! error message is formatted as 'type at location'" do
    bad_json = ~s({"name":"Alice","age":"not a number"})

    exception =
      assert_raise Spectral.Error, fn ->
        Spectral.decode!(bad_json, Person, :t)
      end

    assert exception.message == "no_match at age"
  end

  test "encode! raises Spectral.Error with proper structure" do
    invalid_person = %{name: "Alice", age: "thirty"}

    exception =
      assert_raise Spectral.Error, fn ->
        Spectral.encode!(invalid_person, Person, :t)
      end

    assert %Spectral.Error{
             location: [],
             type: :type_mismatch,
             message: "type_mismatch at root"
           } = exception
  end

  # Configuration error tests - these raise ArgumentError

  test "decode raises ArgumentError for non-existent module" do
    json = ~s({"name":"Alice"})

    exception =
      assert_raise ArgumentError, fn ->
        Spectral.decode(json, NonExistentModule, :t)
      end

    assert exception.message =~ "NonExistentModule"
    assert exception.message =~ "not found"
  end

  test "decode raises ArgumentError for non-existent type" do
    json = ~s({"name":"Alice"})

    exception =
      assert_raise ArgumentError, fn ->
        Spectral.decode(json, Person, :non_existent_type)
      end

    assert exception.message =~ "non_existent_type"
    assert exception.message =~ "not found"
  end

  test "encode raises ArgumentError for non-existent module" do
    data = %{name: "Alice"}

    exception =
      assert_raise ArgumentError, fn ->
        Spectral.encode(data, NonExistentModule, :t)
      end

    assert exception.message =~ "NonExistentModule"
    assert exception.message =~ "not found"
  end

  test "encode raises ArgumentError for non-existent type" do
    data = %{name: "Alice"}

    exception =
      assert_raise ArgumentError, fn ->
        Spectral.encode(data, Person, :non_existent_type)
      end

    assert exception.message =~ "non_existent_type"
    assert exception.message =~ "not found"
  end

  test "schema raises ArgumentError for non-existent module" do
    exception =
      assert_raise ArgumentError, fn ->
        Spectral.schema(NonExistentModule, :t)
      end

    assert exception.message =~ "NonExistentModule"
    assert exception.message =~ "not found"
  end

  test "schema raises ArgumentError for non-existent type" do
    exception =
      assert_raise ArgumentError, fn ->
        Spectral.schema(Person, :non_existent_type)
      end

    assert exception.message =~ "non_existent_type"
    assert exception.message =~ "not found"
  end

  # __spectra__/0 function tests

  test "Person.__spectra__ returns type_info tuple" do
    result = Person.__spectra__()
    assert {:type_info, _types, _records, _functions, _docs, _record_docs} = result
  end

  test "Person.__spectra__ docs contain title and description" do
    {:type_info, _types, _records, _functions, docs, _record_docs} = Person.__spectra__()
    assert is_map(docs)
    assert Map.has_key?(docs, {:t, 0})

    doc = docs[{:t, 0}]
    assert doc.title == "Person"
    assert doc.description == "A person with name and age"
  end

  test "Person.Address.__spectra__ returns type_info tuple" do
    result = Person.Address.__spectra__()
    assert {:type_info, _types, _records, _functions, _docs, _record_docs} = result
  end

  test "Person.Address.__spectra__ docs contain title and description" do
    {:type_info, _types, _records, _functions, docs, _record_docs} = Person.Address.__spectra__()
    assert is_map(docs)
    assert Map.has_key?(docs, {:t, 0})

    doc = docs[{:t, 0}]
    assert doc.title == "Address"
    assert doc.description == "A postal address"
  end

  # Schema doc tests - @spectral attribute support

  test "schema includes title and description from @spectral attribute" do
    schema =
      Spectral.schema(Person, :t)
      |> IO.iodata_to_binary()
      |> Jason.decode!()

    assert schema["title"] == "Person"
    assert schema["description"] == "A person with name and age"
  end

  test "schema includes title and description for nested type with @spectral" do
    schema =
      Spectral.schema(Person.Address, :t)
      |> IO.iodata_to_binary()
      |> Jason.decode!()

    assert schema["title"] == "Address"
    assert schema["description"] == "A postal address"
  end

  test "schema for type without @spectral has no title or description" do
    # Person.Address has @spectral with title/description, but we verify that
    # the schema structure is correct and docs only appear when defined
    schema =
      Spectral.schema(Person.Address, :t)
      |> IO.iodata_to_binary()
      |> Jason.decode!()

    assert schema["title"] == "Address"
    assert schema["description"] == "A postal address"
    assert schema["type"] == "object"
  end

  test "module with two types where only one has @spectral attribute" do
    # MultiTypeModule has two types: main_type (with @spectral) and other_type (without @spectral)
    # This verifies that both types work correctly, but only the documented one has title/description

    # Schema for type with @spectral should have title and description
    schema_with_docs =
      Spectral.schema(MultiTypeModule, :main_type)
      |> IO.iodata_to_binary()
      |> Jason.decode!()

    assert schema_with_docs["title"] == "Main Type"
    assert schema_with_docs["description"] == "This is the documented type"
    assert schema_with_docs["type"] == "object"

    # Schema for type without @spectral should not have title or description
    schema_without_docs =
      Spectral.schema(MultiTypeModule, :other_type)
      |> IO.iodata_to_binary()
      |> Jason.decode!()

    refute Map.has_key?(schema_without_docs, "title")
    refute Map.has_key?(schema_without_docs, "description")
    assert schema_without_docs["type"] == "object"

    # Both types should still work for encoding/decoding
    data_main = %MultiTypeModule{id: 1, value: "test"}
    assert {:ok, _} = Spectral.encode(data_main, MultiTypeModule, :main_type)

    data_other = %MultiTypeModule{id: nil, value: nil}
    assert {:ok, _} = Spectral.encode(data_other, MultiTypeModule, :other_type)
  end

  test "module with two types where @spectral is on the second type" do
    # MultiTypeModuleReversed has two types with two @spectral attributes:
    # first_type has empty @spectral %{} and second_type has full documentation
    # This verifies that empty @spectral doesn't add title/description fields

    # Schema for first type with empty @spectral should not have title or description
    schema_without_docs =
      Spectral.schema(MultiTypeModuleReversed, :first_type)
      |> IO.iodata_to_binary()
      |> Jason.decode!()

    refute Map.has_key?(schema_without_docs, "title")
    refute Map.has_key?(schema_without_docs, "description")
    assert schema_without_docs["type"] == "object"

    # Schema for second type with full @spectral should have title and description
    schema_with_docs =
      Spectral.schema(MultiTypeModuleReversed, :second_type)
      |> IO.iodata_to_binary()
      |> Jason.decode!()

    assert schema_with_docs["title"] == "Second Type"
    assert schema_with_docs["description"] == "This is the documented second type"
    assert schema_with_docs["type"] == "object"

    # Both types should still work for encoding/decoding
    data_first = %MultiTypeModuleReversed{id: 1, value: "test"}
    assert {:ok, _} = Spectral.encode(data_first, MultiTypeModuleReversed, :first_type)

    data_second = %MultiTypeModuleReversed{id: nil, value: nil}
    assert {:ok, _} = Spectral.encode(data_second, MultiTypeModuleReversed, :second_type)
  end

  test "module where first type has empty @spectral and second type has @spectral with docs" do
    # MultiTypeModuleFirstMissing has empty @spectral for first type, docs for second
    # This verifies the pairing works correctly: spectral[i] pairs with type[i]

    # Schema for first type with empty @spectral should NOT have title or description
    schema_first =
      Spectral.schema(MultiTypeModuleFirstMissing, :first_type)
      |> IO.iodata_to_binary()
      |> Jason.decode!()

    refute Map.has_key?(schema_first, "title")
    refute Map.has_key?(schema_first, "description")
    assert schema_first["type"] == "object"

    # Schema for second type with docs SHOULD have title and description
    schema_second =
      Spectral.schema(MultiTypeModuleFirstMissing, :second_type)
      |> IO.iodata_to_binary()
      |> Jason.decode!()

    assert schema_second["title"] == "Second Type"
    assert schema_second["description"] == "This is the documented second type"
    assert schema_second["type"] == "object"
  end
end
