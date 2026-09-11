defmodule SpectralJsonbTest do
  @moduledoc """
  Proves the three ways of putting a Spectral-typed value in a JSONB column.

  A JSONB column never hands Elixir a JSON string. `Ecto.Type.load/3` receives
  the map the database driver already decoded, and `Ecto.Type.dump/3` is
  expected to return a map the driver will encode. So every test here works in
  terms of maps, using `:pre_decoded` and `:pre_encoded`, and pushes the result
  through a real JSON round trip to show it is something a driver can store.
  """
  use ExUnit.Case, async: true

  alias JsonbShapes.Circle
  alias JsonbShapes.Square

  # Stands in for the database driver: whatever `dump/3` returns gets encoded on
  # the way in and decoded on the way out.
  defp through_database(term) do
    term |> :json.encode() |> IO.iodata_to_binary() |> :json.decode()
  end

  describe "self-describing union: discriminator inside the document" do
    test "dumps each variant to a map a driver can store" do
      assert {:ok, dumped} =
               Spectral.encode(%Circle{kind: :circle, radius: 1.5}, JsonbShapes, :shape, :json, [
                 :pre_encoded
               ])

      assert dumped == %{"kind" => "circle", "radius" => 1.5}
      assert dumped == through_database(dumped)
    end

    test "loads each variant back from the stored map" do
      assert {:ok, %Circle{kind: :circle, radius: 1.5}} =
               Spectral.decode(
                 %{"kind" => "circle", "radius" => 1.5},
                 JsonbShapes,
                 :shape,
                 :json,
                 [
                   :pre_decoded
                 ]
               )

      assert {:ok, %Square{kind: :square, side: 2.0}} =
               Spectral.decode(%{"kind" => "square", "side" => 2.0}, JsonbShapes, :shape, :json, [
                 :pre_decoded
               ])
    end

    test "round trips both variants through the database" do
      for value <- [%Circle{kind: :circle, radius: 1.5}, %Square{kind: :square, side: 2.0}] do
        {:ok, dumped} = Spectral.encode(value, JsonbShapes, :shape, :json, [:pre_encoded])

        assert {:ok, ^value} =
                 Spectral.decode(through_database(dumped), JsonbShapes, :shape, :json, [
                   :pre_decoded
                 ])
      end
    end

    test "rejects a document whose tag matches no variant" do
      assert {:error, [%Spectral.Error{type: :no_match}]} =
               Spectral.decode(
                 %{"kind" => "triangle", "base" => 1.0},
                 JsonbShapes,
                 :shape,
                 :json,
                 [:pre_decoded]
               )
    end

    test "generates a schema without any extra wiring" do
      schema = Spectral.schema(JsonbShapes, :shape, :json_schema, [:pre_encoded])

      assert %{anyOf: variants} = schema
      assert length(variants) == 2
    end
  end

  describe "untagged union: why the discriminator field matters" do
    test "the first structurally matching variant wins and extra keys are dropped" do
      stored = %{"name" => "widget", "size" => 3}

      # The later variant describes this document exactly.
      assert {:ok, %JsonbUntaggedShapes.NameAndSize{name: "widget", size: 3}} =
               Spectral.decode(stored, JsonbUntaggedShapes.NameAndSize, :t, :json, [:pre_decoded])

      # Through the union it still decodes as the earlier one, losing `size`.
      assert {:ok, %JsonbUntaggedShapes.Name{name: "widget"}} =
               Spectral.decode(stored, JsonbUntaggedShapes, :payload, :json, [:pre_decoded])
    end
  end

  describe "type chosen by a sibling column" do
    # The row carries the discriminator in its own column, so the payload has no
    # tag of its own and the type reference is supplied at call time.
    defp load_payload(%{kind: kind, payload: payload}) do
      Spectral.decode(payload, JsonbNotification, kind, :json, [:pre_decoded])
    end

    defp dump_payload(%{kind: kind, payload: payload}) do
      Spectral.encode(payload, JsonbNotification, kind, :json, [:pre_encoded])
    end

    test "loads the payload using the type named by the sibling column" do
      row = %{kind: :email, payload: %{"to" => "a@example.com", "subject" => "Hi"}}

      assert {:ok, %JsonbNotification.Email{to: "a@example.com", subject: "Hi"}} =
               load_payload(row)
    end

    test "the same column loads a different type for a different discriminator" do
      row = %{kind: :sms, payload: %{"number" => "+4670", "body" => "Hi"}}

      assert {:ok, %JsonbNotification.Sms{number: "+4670", body: "Hi"}} = load_payload(row)
    end

    test "round trips through the database" do
      payload = %JsonbNotification.Email{to: "a@example.com", subject: "Hi"}

      assert {:ok, dumped} = dump_payload(%{kind: :email, payload: payload})
      assert dumped == %{"to" => "a@example.com", "subject" => "Hi"}

      assert {:ok, ^payload} =
               load_payload(%{kind: :email, payload: through_database(dumped)})
    end

    test "a payload stored under the wrong discriminator fails to load" do
      row = %{kind: :sms, payload: %{"to" => "a@example.com", "subject" => "Hi"}}

      assert {:error, [_ | _]} = load_payload(row)
    end
  end

  describe "discriminating codec: one lookup instead of trying each variant" do
    test "loads the variant named by the tag" do
      assert {:ok, %Circle{kind: :circle, radius: 1.5}} =
               Spectral.decode(
                 %{"kind" => "circle", "radius" => 1.5},
                 JsonbShapeCodec,
                 :shape,
                 :json,
                 [:pre_decoded]
               )

      assert {:ok, %Square{kind: :square, side: 2.0}} =
               Spectral.decode(
                 %{"kind" => "square", "side" => 2.0},
                 JsonbShapeCodec,
                 :shape,
                 :json,
                 [:pre_decoded]
               )
    end

    test "round trips through the database" do
      value = %Square{kind: :square, side: 2.0}

      assert {:ok, dumped} =
               Spectral.encode(value, JsonbShapeCodec, :shape, :json, [:pre_encoded])

      assert dumped == %{"kind" => "square", "side" => 2.0}

      assert {:ok, ^value} =
               Spectral.decode(through_database(dumped), JsonbShapeCodec, :shape, :json, [
                 :pre_decoded
               ])
    end

    test "reports an unknown tag against the discriminated type, not each variant" do
      assert {:error, [%Spectral.Error{type: :type_mismatch}]} =
               Spectral.decode(
                 %{"kind" => "triangle", "base" => 1.0},
                 JsonbShapeCodec,
                 :shape,
                 :json,
                 [:pre_decoded]
               )
    end

    test "rejects a value that is not one of the variants" do
      assert {:error, [%Spectral.Error{type: :type_mismatch}]} =
               Spectral.encode(%{not: "a shape"}, JsonbShapeCodec, :shape, :json, [:pre_encoded])
    end

    test "other types in the codec module fall through to structural handling" do
      assert {:ok, "hello"} =
               Spectral.decode("hello", JsonbShapeCodec, :note, :json, [:pre_decoded])

      assert {:ok, "hello"} =
               Spectral.encode("hello", JsonbShapeCodec, :note, :json, [:pre_encoded])

      # `schema/5` needs its own fallthrough clause, or this raises.
      assert %{type: "string"} =
               Spectral.schema(JsonbShapeCodec, :note, :json_schema, [:pre_encoded])
    end

    test "still generates a schema through the optional callback" do
      schema = Spectral.schema(JsonbShapeCodec, :shape, :json_schema, [:pre_encoded])

      assert %{oneOf: variants} = schema
      assert length(variants) == 2
    end
  end
end
