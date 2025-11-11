defmodule SpectralTest do
  use ExUnit.Case
  doctest Spectral

  test "greets the world" do
    assert Spectral.hello() == :world
  end

  test "encode json" do
    {:ok, jsondata} = Spectral.encode(:json, Person, :t, %Person{name: "Alice", age: 30})
    assert IO.iodata_to_binary(jsondata) == ~s({"age":30,"name":"Alice"})
  end

  test "encode json missing nil value" do
    {:ok, jsondata} = Spectral.encode(:json, Person, :t, %Person{name: "Alice"})
    assert IO.iodata_to_binary(jsondata) == ~s({"name":"Alice"})
  end
end
