defmodule SpectralFieldAliasesTest do
  use ExUnit.Case, async: true

  describe "field_aliases on struct type" do
    test "encode uses aliased key names" do
      data = %FieldAliasesModule{first_name: "Alice", last_name: "Smith", birth_year: 1990}
      {:ok, json_io} = Spectral.encode(data, FieldAliasesModule, :t)
      json = IO.iodata_to_binary(json_io)
      decoded = Jason.decode!(json)
      assert decoded["firstName"] == "Alice"
      assert decoded["lastName"] == "Smith"
      assert decoded["birth_year"] == 1990
      refute Map.has_key?(decoded, "first_name")
      refute Map.has_key?(decoded, "last_name")
    end

    test "decode accepts aliased key names" do
      json = ~s({"firstName":"Bob","lastName":"Jones","birth_year":1985})
      {:ok, result} = Spectral.decode(json, FieldAliasesModule, :t)
      assert result.first_name == "Bob"
      assert result.last_name == "Jones"
      assert result.birth_year == 1985
    end

    test "schema reflects aliased field names" do
      schema =
        Spectral.schema(FieldAliasesModule, :t)
        |> IO.iodata_to_binary()
        |> Jason.decode!()

      props = schema["properties"]
      assert Map.has_key?(props, "firstName")
      assert Map.has_key?(props, "lastName")
      assert Map.has_key?(props, "birth_year")
      refute Map.has_key?(props, "first_name")
      refute Map.has_key?(props, "last_name")
    end
  end

  describe "field_aliases + only compose correctly" do
    test "only is applied first, then aliases on remaining fields" do
      data = %FieldAliasesModule{first_name: "Alice", last_name: "Smith", birth_year: 1990}
      {:ok, json_io} = Spectral.encode(data, FieldAliasesModule, :partial)
      json = IO.iodata_to_binary(json_io)
      decoded = Jason.decode!(json)
      assert decoded["firstName"] == "Alice"
      assert Map.has_key?(decoded, "last_name")
      refute Map.has_key?(decoded, "birth_year")
      refute Map.has_key?(decoded, "first_name")
    end
  end

  describe "field_aliases on map type" do
    test "encode uses aliased key for map literal field" do
      data = %{key: "value"}
      {:ok, json_io} = Spectral.encode(data, FieldAliasesModule, :map_t)
      json = IO.iodata_to_binary(json_io)
      decoded = Jason.decode!(json)
      assert decoded["camelKey"] == "value"
      refute Map.has_key?(decoded, "key")
    end

    test "decode accepts aliased key for map literal field" do
      json = ~s({"camelKey":"hello"})
      {:ok, result} = Spectral.decode(json, FieldAliasesModule, :map_t)
      assert result.key == "hello"
    end
  end

  describe "field_aliases validation" do
    test "invalid aliases value (not binary) raises at compile time" do
      assert_raise ArgumentError, ~r/field_aliases/, fn ->
        Code.eval_string("""
        defmodule InvalidAliasValue do
          use Spectral
          spectral(field_aliases: %{name: 123})
          @type t :: %{name: String.t()}
        end
        """)
      end
    end

    test "invalid aliases (not a map) raises at compile time" do
      assert_raise ArgumentError, ~r/field_aliases/, fn ->
        Code.eval_string("""
        defmodule InvalidAliasType do
          use Spectral
          spectral(field_aliases: [:name])
          @type t :: %{name: String.t()}
        end
        """)
      end
    end
  end
end
