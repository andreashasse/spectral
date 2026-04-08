defmodule SpectralStructDefaultsTest do
  use ExUnit.Case

  # ---------------------------------------------------------------------------
  # Struct defaults — scalar fields
  # ---------------------------------------------------------------------------

  test "non-nullable field with non-nil struct default: uses default when missing from JSON" do
    # score: non_neg_integer(), struct default 100
    json = ~s({"name":"Alice","active":false,"config":{"timeout":10,"retries":1}})
    assert {:ok, %DefaultValues{score: 100}} = Spectral.decode(json, DefaultValues, :t)
  end

  test "nullable field with non-nil struct default: uses struct default when missing" do
    json = ~s({"name":"Alice","score":50,"config":{"timeout":10,"retries":1}})
    assert {:ok, %DefaultValues{active: true}} = Spectral.decode(json, DefaultValues, :t)
  end

  test "non-nullable field with nil struct default: errors when missing from JSON" do
    # name: String.t(), struct default nil → required
    json = ~s({"score":50,"active":true,"config":{"timeout":10,"retries":1}})
    assert {:error, _} = Spectral.decode(json, DefaultValues, :t)
  end

  test "explicit null in JSON overrides non-nil struct default for nullable field" do
    json = ~s({"name":"Alice","score":50,"active":null,"config":{"timeout":10,"retries":1}})
    assert {:ok, %DefaultValues{active: nil}} = Spectral.decode(json, DefaultValues, :t)
  end

  test "all fields present: decoded values take precedence over struct defaults" do
    json = ~s({"name":"Bob","score":42,"active":false,"config":{"timeout":5,"retries":0}})

    assert {:ok,
            %DefaultValues{
              name: "Bob",
              score: 42,
              active: false,
              config: %DefaultValues.Config{timeout: 5, retries: 0}
            }} = Spectral.decode(json, DefaultValues, :t)
  end

  # ---------------------------------------------------------------------------
  # Struct defaults — nested struct field
  # ---------------------------------------------------------------------------

  test "non-nullable nested struct field: struct default used when missing from JSON" do
    # config: Config.t(), struct default %Config{timeout: 30, retries: 3}
    json = ~s({"name":"Alice","score":50,"active":true})

    assert {:ok, %DefaultValues{config: %DefaultValues.Config{timeout: 30, retries: 3}}} =
             Spectral.decode(json, DefaultValues, :t)
  end

  test "nested struct field present: decoded normally with its own struct defaults" do
    # config present but retries missing → Config's struct default 3 fills it in
    json = ~s({"name":"Alice","score":50,"active":true,"config":{"timeout":60}})

    assert {:ok, %DefaultValues{config: %DefaultValues.Config{timeout: 60, retries: 3}}} =
             Spectral.decode(json, DefaultValues, :t)
  end

  test "nested struct field: all sub-fields present decode normally" do
    json = ~s({"name":"Alice","score":50,"active":true,"config":{"timeout":60,"retries":5}})

    assert {:ok, %DefaultValues{config: %DefaultValues.Config{timeout: 60, retries: 5}}} =
             Spectral.decode(json, DefaultValues, :t)
  end

  # ---------------------------------------------------------------------------
  # `only` + struct defaults
  # ---------------------------------------------------------------------------

  test "only: encode excludes score and config, which have non-nil defaults" do
    data = %DefaultValues{
      name: "Alice",
      score: 99,
      active: false,
      config: %DefaultValues.Config{}
    }

    {:ok, json} = Spectral.encode(data, DefaultValues, :public_t)
    decoded = json |> IO.iodata_to_binary() |> Jason.decode!()
    assert decoded == %{"name" => "Alice", "active" => false}
  end

  test "only: excluded non-nil-default fields filled from struct defaults on decode" do
    # score and config are excluded by only: [:name, :active] — struct defaults fill them
    json = ~s({"name":"Alice","active":false})

    assert {:ok,
            %DefaultValues{
              name: "Alice",
              active: false,
              score: 100,
              config: %DefaultValues.Config{timeout: 30, retries: 3}
            }} = Spectral.decode(json, DefaultValues, :public_t)
  end

  test "only: excluded fields present in JSON are ignored, struct defaults still apply" do
    json = ~s({"name":"Alice","active":false,"score":999,"config":{"timeout":1,"retries":1}})

    assert {:ok,
            %DefaultValues{score: 100, config: %DefaultValues.Config{timeout: 30, retries: 3}}} =
             Spectral.decode(json, DefaultValues, :public_t)
  end

  test "only: schema includes only listed fields" do
    schema =
      Spectral.schema(DefaultValues, :public_t)
      |> IO.iodata_to_binary()
      |> Jason.decode!()

    assert Map.has_key?(schema["properties"], "name")
    assert Map.has_key?(schema["properties"], "active")
    refute Map.has_key?(schema["properties"], "score")
    refute Map.has_key?(schema["properties"], "config")
  end

  # ---------------------------------------------------------------------------
  # Ecto-style timestamps in the type (not excluded with `only`)
  #
  # Ecto's timestamps() adds inserted_at and updated_at with nil defaults.
  # Including them in the type (as T | nil) means:
  #   - Encode: omitted when nil (e.g. before the record is persisted)
  #   - Decode: get nil when absent from JSON (e.g. a client create request)
  # The same type therefore works for both write requests and read responses.
  # ---------------------------------------------------------------------------

  test "ecto timestamps: missing from JSON on create request → nil, no error" do
    json = ~s({"name":"Alice","email":"alice@example.com"})

    assert {:ok,
            %EctoUser{
              name: "Alice",
              email: "alice@example.com",
              inserted_at: nil,
              updated_at: nil
            }} =
             Spectral.decode(json, EctoUser, :t)
  end

  test "ecto timestamps: present in JSON on read response → decoded normally" do
    json =
      ~s({"name":"Alice","email":"alice@example.com","inserted_at":"2024-01-01T00:00:00Z","updated_at":"2024-06-01T12:00:00Z"})

    assert {:ok,
            %EctoUser{
              name: "Alice",
              email: "alice@example.com",
              inserted_at: "2024-01-01T00:00:00Z",
              updated_at: "2024-06-01T12:00:00Z"
            }} = Spectral.decode(json, EctoUser, :t)
  end

  test "ecto timestamps: nil on encode → omitted from JSON" do
    user = %EctoUser{name: "Alice", email: "alice@example.com"}
    {:ok, json} = Spectral.encode(user, EctoUser, :t)
    decoded = json |> IO.iodata_to_binary() |> Jason.decode!()
    assert decoded == %{"name" => "Alice", "email" => "alice@example.com"}
    refute Map.has_key?(decoded, "inserted_at")
    refute Map.has_key?(decoded, "updated_at")
  end

  test "ecto timestamps: set on encode → included in JSON" do
    user = %EctoUser{
      name: "Alice",
      email: "alice@example.com",
      inserted_at: "2024-01-01T00:00:00Z",
      updated_at: "2024-06-01T12:00:00Z"
    }

    {:ok, json} = Spectral.encode(user, EctoUser, :t)
    decoded = json |> IO.iodata_to_binary() |> Jason.decode!()

    assert decoded == %{
             "name" => "Alice",
             "email" => "alice@example.com",
             "inserted_at" => "2024-01-01T00:00:00Z",
             "updated_at" => "2024-06-01T12:00:00Z"
           }
  end

  # ---------------------------------------------------------------------------
  # All-nil-default baseline: existing Person behaviour is unchanged
  # ---------------------------------------------------------------------------

  test "all-nil defaults: missing nullable field still decodes to nil" do
    # Person.age: non_neg_integer() | nil, nil default — should still be nil
    assert {:ok, %Person{age: nil}} = Spectral.decode(~s({"name":"Alice"}), Person, :t)
  end

  test "all-nil defaults: missing non-nullable field still errors" do
    assert {:error, _} = Spectral.decode(~s({"age":30}), Person, :t)
  end
end
