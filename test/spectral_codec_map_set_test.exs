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
               Spectral.Codec.MapSet.encode(:json, MapSet, {:type, :t, 0}, ms, :undefined)

      assert Enum.sort(result) == [1, 2, 3]
    end

    test "encodes MapSet to list (t/1)" do
      ms = MapSet.new(["a", "b"])

      assert {:ok, result} =
               Spectral.Codec.MapSet.encode(:json, MapSet, {:type, :t, 1}, ms, :undefined)

      assert Enum.sort(result) == ["a", "b"]
    end

    test "encode returns error for non-MapSet (t/0)" do
      assert {:error, [error]} =
               Spectral.Codec.MapSet.encode(:json, MapSet, {:type, :t, 0}, [1, 2, 3], :undefined)

      assert %Spectral.Error{type: :type_mismatch} = Spectral.Error.from_erlang(error)
    end

    test "encode returns error for non-MapSet (t/1)" do
      assert {:error, [error]} =
               Spectral.Codec.MapSet.encode(
                 :json,
                 MapSet,
                 {:type, :t, 1},
                 "not a mapset",
                 :undefined
               )

      assert %Spectral.Error{type: :type_mismatch} = Spectral.Error.from_erlang(error)
    end
  end

  describe "Spectral.Codec.MapSet - decode" do
    test "decodes list to MapSet (t/0)" do
      assert {:ok, ms} =
               Spectral.Codec.MapSet.decode(:json, MapSet, {:type, :t, 0}, [1, 2, 3], :undefined)

      assert ms == MapSet.new([1, 2, 3])
    end

    test "decodes list to MapSet (t/1)" do
      assert {:ok, ms} =
               Spectral.Codec.MapSet.decode(:json, MapSet, {:type, :t, 1}, ["a", "b"], :undefined)

      assert ms == MapSet.new(["a", "b"])
    end

    test "decode returns error for non-list (t/0)" do
      assert {:error, [error]} =
               Spectral.Codec.MapSet.decode(
                 :json,
                 MapSet,
                 {:type, :t, 0},
                 "not a list",
                 :undefined
               )

      assert %Spectral.Error{type: :type_mismatch} = Spectral.Error.from_erlang(error)
    end

    test "decode returns error for non-list (t/1)" do
      assert {:error, [error]} =
               Spectral.Codec.MapSet.decode(:json, MapSet, {:type, :t, 1}, 42, :undefined)

      assert %Spectral.Error{type: :type_mismatch} = Spectral.Error.from_erlang(error)
    end
  end

  describe "Spectral.Codec.MapSet - schema" do
    test "schema returns array with uniqueItems (t/0)" do
      assert %{type: "array", uniqueItems: true} =
               Spectral.Codec.MapSet.schema(:json, MapSet, {:type, :t, 0}, :undefined)
    end

    test "schema returns array with uniqueItems (t/1)" do
      assert %{type: "array", uniqueItems: true} =
               Spectral.Codec.MapSet.schema(:json, MapSet, {:type, :t, 1}, :undefined)
    end
  end
end
