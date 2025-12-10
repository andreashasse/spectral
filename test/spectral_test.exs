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
end
