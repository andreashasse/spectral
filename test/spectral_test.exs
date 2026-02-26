defmodule SpectralTest do
  use ExUnit.Case
  doctest Spectral

  # Import Erlang record definitions from spectra
  require Record

  # Extract record definitions from spectra's internal header
  Record.defrecord(
    :type_info,
    Record.extract(:type_info, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecord(
    :sp_map,
    Record.extract(:sp_map, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecord(
    :sp_simple_type,
    Record.extract(:sp_simple_type, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecord(
    :sp_remote_type,
    Record.extract(:sp_remote_type, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecord(
    :literal_map_field,
    Record.extract(:literal_map_field, from_lib: "spectra/include/spectra_internal.hrl")
  )

  Record.defrecord(
    :sp_user_type_ref,
    Record.extract(:sp_user_type_ref, from_lib: "spectra/include/spectra_internal.hrl")
  )

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
                    literal_map_field(
                      kind: :exact,
                      name: :name,
                      binary_name: "name",
                      val_type: sp_remote_type(mfargs: {String, :t, []})
                    ),
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
                  type: sp_map(struct_name: Person),
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

  # __spectra_type_info__/0 function tests

  test "Person.__spectra_type_info__ returns type_info tuple" do
    result = Person.__spectra_type_info__()
    assert type_info(types: _types, records: _records, functions: _functions) = result
  end

  test "Person.__spectra_type_info__ docs contain title and description" do
    type_info(types: types) = Person.__spectra_type_info__()
    assert is_map(types)
    assert Map.has_key?(types, {:t, 0})

    # The type itself now contains the doc in its meta field
    sp_map(meta: meta) = types[{:t, 0}]
    assert is_map(meta)
    assert Map.has_key?(meta, :doc)

    doc = meta[:doc]
    assert doc.title == "Person"
    assert doc.description == "A person with name and age"
  end

  test "Person.Address.__spectra_type_info__ returns type_info tuple" do
    result = Person.Address.__spectra_type_info__()
    assert type_info(types: _types, records: _records, functions: _functions) = result
  end

  test "Person.Address.__spectra_type_info__ docs contain title and description" do
    type_info(types: types) = Person.Address.__spectra_type_info__()
    assert is_map(types)
    assert Map.has_key?(types, {:t, 0})

    # The type itself now contains the doc in its meta field
    sp_map(meta: meta) = types[{:t, 0}]
    assert is_map(meta)
    assert Map.has_key?(meta, :doc)

    doc = meta[:doc]
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

  test "schema for type without spectral has no title or description" do
    # MultiTypeModule.other_type has NO spectral documentation
    # Verify that the schema has no title/description fields
    schema =
      Spectral.schema(MultiTypeModule, :other_type)
      |> IO.iodata_to_binary()
      |> Jason.decode!()

    refute Map.has_key?(schema, "title")
    refute Map.has_key?(schema, "description")
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

  test "semantic pairing: documentation assigned to type AFTER spectral call, not by index" do
    # This test validates the critical bug fix: documentation should be paired
    # based on line position (semantic), not array index (positional).
    #
    # Before the fix, documentation would be incorrectly assigned by index:
    #   spectral[0] → type[0], even if spectral[0] appeared after type[0] in source
    #
    # After the fix, documentation is correctly assigned:
    #   each spectral call documents the first @type defined after it

    # Check __spectra_type_info__() function instead of beam attributes
    type_info(types: types) = SemanticPairingTestModule.__spectra_type_info__()

    # Should have exactly 2 types (documented and undocumented)
    assert map_size(types) == 2

    # Check documented type has docs in meta
    sp_simple_type(meta: documented_meta) = types[{:documented, 0}]
    assert Map.has_key?(documented_meta, :doc)
    assert documented_meta[:doc][:title] == "Documented"
    assert documented_meta[:doc][:description] == "This type has docs"

    # Check undocumented type has no docs in meta
    sp_simple_type(meta: undocumented_meta) = types[{:undocumented, 0}]
    refute Map.has_key?(undocumented_meta, :doc)

    # Verify schema for undocumented type has NO title/description
    schema_undoc =
      Spectral.schema(SemanticPairingTestModule, :undocumented)
      |> IO.iodata_to_binary()
      |> Jason.decode!()

    refute Map.has_key?(schema_undoc, "title")
    refute Map.has_key?(schema_undoc, "description")

    # Verify schema for documented type HAS title/description
    schema_doc =
      Spectral.schema(SemanticPairingTestModule, :documented)
      |> IO.iodata_to_binary()
      |> Jason.decode!()

    assert schema_doc["title"] == "Documented"
    assert schema_doc["description"] == "This type has docs"
  end

  # Error handling tests for type AST validation

  test "spectral works with types that have parameters" do
    # This should work without errors - testing the defensive is_atom(name) guard
    type_info(types: types) = TypeWithParams.__spectra_type_info__()
    assert Map.has_key?(types, {:generic, 1})

    # Verify the type has documentation
    # Use :spectra_type.get_meta/1 to extract meta from any sp_type
    type = types[{:generic, 1}]
    meta = :spectra_type.get_meta(type)

    assert is_map(meta)
    assert meta[:doc][:title] == "Generic"
    assert meta[:doc][:description] == "A generic type"
  end
end
