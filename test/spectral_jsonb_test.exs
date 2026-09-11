defmodule SpectralJsonbTest do
  @moduledoc """
  Proves the two ways of putting a Spectral-typed value in a JSONB column.

  A JSONB column never hands Elixir a JSON string. `Ecto.Type.load/3` receives
  the map the database driver already decoded, and `Ecto.Type.dump/3` is
  expected to return a map the driver will encode. So every test here works in
  terms of maps, using `:pre_decoded` and `:pre_encoded`.

  Nothing here exercises Ecto or a database. The round trip below only shows
  that an encoded value survives JSON serialization, which is the property a
  driver needs. Testing the Ecto type itself needs Ecto and a real Postgres
  instance, which is why that lives outside this repository.
  """
  use ExUnit.Case, async: true

  alias JsonbShapes.Circle
  alias JsonbShapes.Square

  # Shows the dumped value is JSON-serializable. Not a database, not Ecto.
  defp json_round_trip(term) do
    term |> :json.encode() |> IO.iodata_to_binary() |> :json.decode()
  end

  describe "self-describing union: discriminator inside the document" do
    test "dumps each variant to a JSON-serializable map" do
      assert {:ok, dumped} =
               Spectral.encode(%Circle{radius: 1.5}, JsonbShapes, :shape, :json, [:pre_encoded])

      assert dumped == %{"kind" => "circle", "radius" => 1.5}
      assert dumped == json_round_trip(dumped)
    end

    test "the tag comes from the struct default, so callers never write it" do
      assert %Circle{kind: :circle} = %Circle{radius: 1.5}
      assert %Square{kind: :square} = %Square{side: 2.0}
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

    test "round trips both variants" do
      for value <- [%Circle{radius: 1.5}, %Square{side: 2.0}] do
        {:ok, dumped} = Spectral.encode(value, JsonbShapes, :shape, :json, [:pre_encoded])

        assert {:ok, ^value} =
                 Spectral.decode(json_round_trip(dumped), JsonbShapes, :shape, :json, [
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
    defp decode_payload(%{kind: kind, payload: payload}) do
      Spectral.decode(payload, JsonbNotification, kind, :json, [:pre_decoded])
    end

    defp encode_payload(%{kind: kind, payload: payload}) do
      Spectral.encode(payload, JsonbNotification, kind, :json, [:pre_encoded])
    end

    test "loads the payload using the type named by the sibling column" do
      row = %{kind: :email, payload: %{"to" => "a@example.com", "subject" => "Hi"}}

      assert {:ok, %JsonbNotification.Email{to: "a@example.com", subject: "Hi"}} =
               decode_payload(row)
    end

    test "the same column loads a different type for a different discriminator" do
      row = %{kind: :sms, payload: %{"number" => "+4670", "body" => "Hi"}}

      assert {:ok, %JsonbNotification.Sms{number: "+4670", body: "Hi"}} = decode_payload(row)
    end

    test "round trips" do
      payload = %JsonbNotification.Email{to: "a@example.com", subject: "Hi"}

      assert {:ok, dumped} = encode_payload(%{kind: :email, payload: payload})
      assert dumped == %{"to" => "a@example.com", "subject" => "Hi"}

      assert {:ok, ^payload} =
               decode_payload(%{kind: :email, payload: json_round_trip(dumped)})
    end

    test "a payload stored under the wrong discriminator fails to load" do
      row = %{kind: :sms, payload: %{"to" => "a@example.com", "subject" => "Hi"}}

      assert {:error, [_ | _]} = decode_payload(row)
    end
  end
end
