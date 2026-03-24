defmodule SpectralCodecMapSetTest do
  use ExUnit.Case, async: false

  setup_all do
    Application.put_env(:spectra, :codecs, %{
      {MapSet, {:type, :t, 0}} => Spectral.Codec.MapSet,
      {MapSet, {:type, :t, 1}} => Spectral.Codec.MapSet
    })

    on_exit(fn -> Application.delete_env(:spectra, :codecs) end)
  end

  describe "Spectral.Codec.MapSet - encode" do
    test "encodes MapSet to list (t/0)" do
      ms = MapSet.new([1, 2, 3])

      assert {:ok, result} =
               Spectral.Codec.MapSet.encode(
                 :json,
                 MapSet,
                 {:type, :t, 0},
                 ms,
                 :undefined,
                 :undefined
               )

      assert Enum.sort(result) == [1, 2, 3]
    end

    test "encodes MapSet to list (t/1)" do
      ms = MapSet.new(["a", "b"])

      assert {:ok, result} =
               Spectral.Codec.MapSet.encode(
                 :json,
                 MapSet,
                 {:type, :t, 1},
                 ms,
                 :undefined,
                 :undefined
               )

      assert Enum.sort(result) == ["a", "b"]
    end

    test "encode returns error for non-MapSet (t/0)" do
      assert {:error, [error]} =
               Spectral.Codec.MapSet.encode(
                 :json,
                 MapSet,
                 {:type, :t, 0},
                 [1, 2, 3],
                 :undefined,
                 :undefined
               )

      assert %Spectral.Error{type: :type_mismatch} = Spectral.Error.from_erlang(error)
    end

    test "encode returns error for non-MapSet (t/1)" do
      assert {:error, [error]} =
               Spectral.Codec.MapSet.encode(
                 :json,
                 MapSet,
                 {:type, :t, 1},
                 "not a mapset",
                 :undefined,
                 :undefined
               )

      assert %Spectral.Error{type: :type_mismatch} = Spectral.Error.from_erlang(error)
    end
  end

  describe "Spectral.Codec.MapSet - decode" do
    test "decodes list to MapSet (t/0)" do
      assert {:ok, ms} =
               Spectral.Codec.MapSet.decode(
                 :json,
                 MapSet,
                 {:type, :t, 0},
                 [1, 2, 3],
                 :undefined,
                 :undefined
               )

      assert ms == MapSet.new([1, 2, 3])
    end

    test "decodes list to MapSet (t/1)" do
      assert {:ok, ms} =
               Spectral.Codec.MapSet.decode(
                 :json,
                 MapSet,
                 {:type, :t, 1},
                 ["a", "b"],
                 :undefined,
                 :undefined
               )

      assert ms == MapSet.new(["a", "b"])
    end

    test "decode returns error for non-list (t/0)" do
      assert {:error, [error]} =
               Spectral.Codec.MapSet.decode(
                 :json,
                 MapSet,
                 {:type, :t, 0},
                 "not a list",
                 :undefined,
                 :undefined
               )

      assert %Spectral.Error{type: :type_mismatch} = Spectral.Error.from_erlang(error)
    end

    test "decode returns error for non-list (t/1)" do
      assert {:error, [error]} =
               Spectral.Codec.MapSet.decode(
                 :json,
                 MapSet,
                 {:type, :t, 1},
                 42,
                 :undefined,
                 :undefined
               )

      assert %Spectral.Error{type: :type_mismatch} = Spectral.Error.from_erlang(error)
    end
  end

  describe "Spectral.Codec.MapSet - schema" do
    test "schema returns array with uniqueItems (t/0)" do
      assert %{type: "array", uniqueItems: true} =
               Spectral.Codec.MapSet.schema(
                 :json_schema,
                 MapSet,
                 {:type, :t, 0},
                 :undefined,
                 :undefined
               )
    end

    test "schema returns array with uniqueItems (t/1) without type args" do
      assert %{type: "array", uniqueItems: true} =
               Spectral.Codec.MapSet.schema(
                 :json_schema,
                 MapSet,
                 {:type, :t, 1},
                 :undefined,
                 :undefined
               )
    end
  end

  describe "Spectral.Codec.MapSet - t/1 element-type-aware (integration)" do
    test "encode recursively encodes elements according to their type" do
      ms = MapSet.new([1, 2, 3])
      assert {:ok, json} = Spectral.encode(ms, MapSetModule, :int_set)
      decoded = json |> Jason.decode!() |> Enum.sort()
      assert decoded == [1, 2, 3]
    end

    test "decode recursively decodes elements and rejects wrong types" do
      json = ~s([1, 2, 3])
      assert {:ok, ms} = Spectral.decode(json, MapSetModule, :int_set)
      assert ms == MapSet.new([1, 2, 3])
    end

    test "decode returns error when an element has the wrong type" do
      json = ~s([1, "not_an_int", 3])
      assert {:error, [_ | _]} = Spectral.decode(json, MapSetModule, :int_set)
    end

    test "schema includes items constraint for typed elements" do
      schema = Spectral.schema(MapSetModule, :int_set, :json_schema, [:pre_encoded])
      assert %{type: "array", uniqueItems: true, items: %{type: "integer"}} = schema
    end
  end
end
