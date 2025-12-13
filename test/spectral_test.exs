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

  test "schema! returns result directly" do
    assert ~s({"type":"object","required":["street","city"],"additionalProperties":false,"properties":{"city":{"type":"string"},"street":{"type":"string"}}}) ==
             Spectral.schema!(Person.Address, :t)
             |> IO.iodata_to_binary()
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
                  value: %{name: "Alice", age: "thirty"},
                  expected_struct: Person
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
end
