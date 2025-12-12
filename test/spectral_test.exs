defmodule SpectralTest do
  use ExUnit.Case
  doctest Spectral

  test "encode json" do
    {:ok, jsondata} = Spectral.encode(%Person{name: "Alice", age: 30}, Person, :t)
    assert IO.iodata_to_binary(jsondata) == ~s({"age":30,"name":"Alice"})
  end

  test "encode json missing nil value" do
    {:ok, jsondata} = Spectral.encode(%Person{name: "Alice"}, Person, :t)
    assert IO.iodata_to_binary(jsondata) == ~s({"name":"Alice"})
  end

  test "encode with pipe" do
    result =
      %Person{name: "Alice", age: 30}
      |> Spectral.encode(Person, :t)

    assert {:ok, _jsondata} = result
  end

  test "decode json" do
    {:ok, person} = Spectral.decode(~s({"name":"Alice","age":30}), Person, :t)
    assert person == %Person{name: "Alice", age: 30, address: nil}
  end

  test "decode with pipe" do
    result =
      ~s({"name":"Alice","age":30})
      |> Spectral.decode(Person, :t)

    assert {:ok, %Person{name: "Alice", age: 30}} = result
  end

  test "encode! returns result directly" do
    result =
      %Person{name: "Alice", age: 30}
      |> Spectral.encode!(Person, :t)
      |> IO.iodata_to_binary()

    assert result == ~s({"age":30,"name":"Alice"})
  end

  test "decode! returns result directly" do
    person = Spectral.decode!(~s({"name":"Alice","age":30}), Person, :t)
    assert person == %Person{name: "Alice", age: 30, address: nil}
  end

  test "schema! returns result directly" do
    schema = Spectral.schema!(Person, :t)
    assert is_binary(IO.iodata_to_binary(schema))
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
                context: :undefined
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
                context: %{type: type, value: value}
              }
            ]} = Spectral.decode(bad_json, Person, :t)

    # Context should contain the type spec and the invalid value
    assert value == "not a number"
    assert type != nil
  end

  test "encode returns error for invalid data type" do
    # Trying to encode with wrong type - age as string when integer expected
    invalid_person = %{name: "Alice", age: "thirty"}

    assert {:error,
            [
              %Spectral.Error{
                location: location,
                type: error_type,
                context: context
              }
            ]} = Spectral.encode(invalid_person, Person, :t)

    assert is_list(location)
    assert is_atom(error_type)
    assert context != nil
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

    # Message is auto-generated when raised as exception
    assert is_binary(exception.message)
    assert exception.message =~ "age"
  end

  test "decode! error message is formatted as 'type at location'" do
    bad_json = ~s({"name":"Alice","age":"not a number"})

    exception =
      assert_raise Spectral.Error, fn ->
        Spectral.decode!(bad_json, Person, :t)
      end

    # Message should be in format "type at location"
    assert exception.message == "no_match at age"
  end

  test "encode! raises Spectral.Error with proper structure" do
    invalid_person = %{name: "Alice", age: "thirty"}

    exception =
      assert_raise Spectral.Error, fn ->
        Spectral.encode!(invalid_person, Person, :t)
      end

    # Verify the error structure
    assert %Spectral.Error{
             location: location,
             type: type
           } = exception

    assert is_list(location)
    assert is_atom(type)
    # Message is auto-generated when raised as exception
    assert is_binary(exception.message)
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
end
