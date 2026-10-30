defmodule SpectralCodecNaiveDateTimeTimeTest do
  use ExUnit.Case, async: true

  @value %TimeValuesModule{
    naive: ~N[2024-01-02 03:04:05.123456],
    time: ~T[13:14:15],
    maybe_naive: nil,
    maybe_time: nil
  }

  @json %{
    "naive" => "2024-01-02T03:04:05.123456",
    "time" => "13:14:15",
    "maybe_naive" => nil,
    "maybe_time" => nil
  }

  describe "struct with NaiveDateTime and Time fields" do
    test "encodes to ISO 8601 strings" do
      assert {:ok, encoded} = Spectral.encode(@value, TimeValuesModule, :t, :json, [:pre_encoded])
      assert encoded["naive"] == "2024-01-02T03:04:05.123456"
      assert encoded["time"] == "13:14:15"
      refute Map.has_key?(encoded, "maybe_naive")
      refute Map.has_key?(encoded, "maybe_time")
    end

    test "encodes the optional fields when set" do
      value = %{@value | maybe_naive: ~N[2024-05-06 07:08:09], maybe_time: ~T[01:02:03.5]}

      assert {:ok, encoded} = Spectral.encode(value, TimeValuesModule, :t, :json, [:pre_encoded])
      assert encoded["maybe_naive"] == "2024-05-06T07:08:09"
      assert encoded["maybe_time"] == "01:02:03.5"
    end

    test "decodes from ISO 8601 strings" do
      assert {:ok, @value} = Spectral.decode(@json, TimeValuesModule, :t, :json, [:pre_decoded])
    end

    test "round-trips through JSON" do
      value = %{@value | maybe_naive: ~N[2024-05-06 07:08:09], maybe_time: ~T[01:02:03]}
      {:ok, json} = Spectral.encode(value, TimeValuesModule, :t)
      assert {:ok, ^value} = Spectral.decode(IO.iodata_to_binary(json), TimeValuesModule, :t)
    end

    test "decode rejects a badly formatted NaiveDateTime" do
      json = %{@json | "naive" => "yesterday"}

      assert {:error, [%Spectral.Error{location: [:naive], context: %{reason: :invalid_format}}]} =
               Spectral.decode(json, TimeValuesModule, :t, :json, [:pre_decoded])
    end

    test "decode rejects a badly formatted Time" do
      json = %{@json | "time" => "25:00:00"}

      assert {:error, [%Spectral.Error{location: [:time], context: %{reason: :invalid_format}}]} =
               Spectral.decode(json, TimeValuesModule, :t, :json, [:pre_decoded])
    end

    test "decode rejects non-string input" do
      json = %{@json | "time" => 12}

      assert {:error, [%Spectral.Error{location: [:time], type: :type_mismatch}]} =
               Spectral.decode(json, TimeValuesModule, :t, :json, [:pre_decoded])
    end

    test "encode rejects a value of the wrong type" do
      value = %{@value | naive: ~D[2024-01-02]}

      assert {:error, [%Spectral.Error{location: [:naive], type: :type_mismatch}]} =
               Spectral.encode(value, TimeValuesModule, :t, :json, [:pre_encoded])
    end

    test "schema describes the fields as strings without an offset format" do
      schema = Spectral.schema(TimeValuesModule, :t, :json_schema, [:pre_encoded])
      props = schema[:properties]

      assert %{type: "string", pattern: naive_pattern} = props["naive"]
      assert %{type: "string", pattern: time_pattern} = props["time"]
      refute Map.has_key?(props["naive"], :format)
      refute Map.has_key?(props["time"], :format)
      assert Regex.match?(Regex.compile!(naive_pattern), "2024-01-02T03:04:05.123456")
      assert Regex.match?(Regex.compile!(naive_pattern), "2024-01-02T03:04:05")
      refute Regex.match?(Regex.compile!(naive_pattern), "2024-01-02T03:04:05Z")
      assert Regex.match?(Regex.compile!(time_pattern), "13:14:15.5")
      refute Regex.match?(Regex.compile!(time_pattern), "13:14:15+01:00")
    end
  end

  describe "codecs called directly" do
    test "NaiveDateTime :string format uses charlists" do
      assert {:ok, ~c"2024-01-02T03:04:05"} =
               Spectral.Codec.NaiveDateTime.encode(
                 :string,
                 :undefined,
                 {:type, :t, 0},
                 :undefined,
                 ~N[2024-01-02 03:04:05],
                 :undefined
               )

      assert {:ok, ~N[2024-01-02 03:04:05]} =
               Spectral.Codec.NaiveDateTime.decode(
                 :string,
                 :undefined,
                 {:type, :t, 0},
                 :undefined,
                 ~c"2024-01-02T03:04:05",
                 :undefined
               )

      assert {:error, [{:sp_error, [], :type_mismatch, %{reason: :invalid_format}}]} =
               Spectral.Codec.NaiveDateTime.decode(
                 :string,
                 :undefined,
                 {:type, :t, 0},
                 :undefined,
                 ~c"nope",
                 :undefined
               )
    end

    test "Time :string format uses charlists" do
      assert {:ok, ~c"13:14:15"} =
               Spectral.Codec.Time.encode(
                 :string,
                 :undefined,
                 {:type, :t, 0},
                 :undefined,
                 ~T[13:14:15],
                 :undefined
               )

      assert {:ok, ~T[13:14:15]} =
               Spectral.Codec.Time.decode(
                 :string,
                 :undefined,
                 {:type, :t, 0},
                 :undefined,
                 ~c"13:14:15",
                 :undefined
               )

      assert {:error, [{:sp_error, [], :type_mismatch, %{reason: :invalid_format}}]} =
               Spectral.Codec.Time.decode(
                 :string,
                 :undefined,
                 {:type, :t, 0},
                 :undefined,
                 ~c"nope",
                 :undefined
               )
    end

    test "both codecs return :binary_string as a binary" do
      assert {:ok, "2024-01-02T03:04:05"} =
               Spectral.Codec.NaiveDateTime.encode(
                 :binary_string,
                 :undefined,
                 {:type, :t, 0},
                 :undefined,
                 ~N[2024-01-02 03:04:05],
                 :undefined
               )

      assert {:ok, ~T[13:14:15]} =
               Spectral.Codec.Time.decode(
                 :binary_string,
                 :undefined,
                 {:type, :t, 0},
                 :undefined,
                 "13:14:15",
                 :undefined
               )
    end
  end

  test "the codecs are registered at startup" do
    codecs = Application.get_env(:spectra, :codecs)
    assert codecs[{NaiveDateTime, {:type, :t, 0}}] == Spectral.Codec.NaiveDateTime
    assert codecs[{Time, {:type, :t, 0}}] == Spectral.Codec.Time
  end
end
