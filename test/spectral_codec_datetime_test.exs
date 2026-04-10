defmodule SpectralCodecDateTimeTest do
  use ExUnit.Case, async: false

  setup_all do
    Application.put_env(:spectra, :codecs, %{
      {DateTime, {:type, :t, 0}} => Spectral.Codec.DateTime,
      {Date, {:type, :t, 0}} => Spectral.Codec.Date
    })

    on_exit(fn -> Application.delete_env(:spectra, :codecs) end)
  end

  describe "Spectral.Codec.DateTime" do
    test "encodes DateTime to ISO 8601 binary" do
      {:ok, dt, _} = DateTime.from_iso8601("2012-04-23T18:25:43.511Z")

      assert {:ok, "2012-04-23T18:25:43.511Z"} =
               Spectral.Codec.DateTime.encode(
                 :json,
                 DateTime,
                 {:type, :t, 0},
                 dt,
                 :undefined,
                 :undefined,
                 :undefined
               )
    end

    test "encodes DateTime to charlist for :string format" do
      {:ok, dt, _} = DateTime.from_iso8601("2012-04-23T18:25:43.511Z")

      assert {:ok, ~c"2012-04-23T18:25:43.511Z"} =
               Spectral.Codec.DateTime.encode(
                 :string,
                 DateTime,
                 {:type, :t, 0},
                 dt,
                 :undefined,
                 :undefined,
                 :undefined
               )
    end

    test "encode returns error for non-DateTime" do
      assert {:error, [_]} =
               Spectral.Codec.DateTime.encode(
                 :json,
                 DateTime,
                 {:type, :t, 0},
                 "not a datetime",
                 :undefined,
                 :undefined,
                 :undefined
               )
    end

    test "decodes ISO 8601 binary to DateTime" do
      {:ok, dt, _} = DateTime.from_iso8601("2012-04-23T18:25:43.511Z")

      assert {:ok, ^dt} =
               Spectral.Codec.DateTime.decode(
                 :json,
                 DateTime,
                 {:type, :t, 0},
                 "2012-04-23T18:25:43.511Z",
                 :undefined,
                 :undefined,
                 :undefined
               )
    end

    test "decodes ISO 8601 charlist to DateTime for :string format" do
      {:ok, dt, _} = DateTime.from_iso8601("2012-04-23T18:25:43.511Z")

      assert {:ok, ^dt} =
               Spectral.Codec.DateTime.decode(
                 :string,
                 DateTime,
                 {:type, :t, 0},
                 ~c"2012-04-23T18:25:43.511Z",
                 :undefined,
                 :undefined,
                 :undefined
               )
    end

    test "decode returns type_mismatch with invalid_format reason for badly formatted string" do
      {:error, [error]} =
        Spectral.Codec.DateTime.decode(
          :json,
          DateTime,
          {:type, :t, 0},
          "not-a-date",
          :undefined,
          :undefined,
          :undefined
        )

      assert %Spectral.Error{type: :type_mismatch, context: %{reason: :invalid_format}} =
               Spectral.Error.from_erlang(error)
    end

    test "decode returns type_mismatch for non-string input" do
      {:error, [error]} =
        Spectral.Codec.DateTime.decode(
          :json,
          DateTime,
          {:type, :t, 0},
          12_345,
          :undefined,
          :undefined,
          :undefined
        )

      assert %Spectral.Error{type: :type_mismatch, context: ctx} =
               Spectral.Error.from_erlang(error)

      refute Map.has_key?(ctx, :reason)
    end

    test "encodes DateTime to binary string for :binary_string format" do
      {:ok, dt, _} = DateTime.from_iso8601("2012-04-23T18:25:43.511Z")

      assert {:ok, "2012-04-23T18:25:43.511Z"} =
               Spectral.Codec.DateTime.encode(
                 :binary_string,
                 DateTime,
                 {:type, :t, 0},
                 dt,
                 :undefined,
                 :undefined,
                 :undefined
               )
    end

    test "decodes ISO 8601 binary to DateTime for :binary_string format" do
      {:ok, dt, _} = DateTime.from_iso8601("2012-04-23T18:25:43.511Z")

      assert {:ok, ^dt} =
               Spectral.Codec.DateTime.decode(
                 :binary_string,
                 DateTime,
                 {:type, :t, 0},
                 "2012-04-23T18:25:43.511Z",
                 :undefined,
                 :undefined,
                 :undefined
               )
    end

    test "schema returns date-time format" do
      assert %{type: "string", format: "date-time"} =
               Spectral.Codec.DateTime.schema(
                 :json_schema,
                 DateTime,
                 {:type, :t, 0},
                 :undefined,
                 :undefined,
                 :undefined
               )
    end
  end

  describe "Spectral.Codec.Date" do
    test "encodes Date to ISO 8601 binary" do
      {:ok, d} = Date.from_iso8601("2023-04-01")

      assert {:ok, "2023-04-01"} =
               Spectral.Codec.Date.encode(
                 :json,
                 Date,
                 {:type, :t, 0},
                 d,
                 :undefined,
                 :undefined,
                 :undefined
               )
    end

    test "encodes Date to charlist for :string format" do
      {:ok, d} = Date.from_iso8601("2023-04-01")

      assert {:ok, ~c"2023-04-01"} =
               Spectral.Codec.Date.encode(
                 :string,
                 Date,
                 {:type, :t, 0},
                 d,
                 :undefined,
                 :undefined,
                 :undefined
               )
    end

    test "encode returns error for non-Date" do
      assert {:error, [_]} =
               Spectral.Codec.Date.encode(
                 :json,
                 Date,
                 {:type, :t, 0},
                 "not a date",
                 :undefined,
                 :undefined,
                 :undefined
               )
    end

    test "decodes ISO 8601 binary to Date" do
      {:ok, d} = Date.from_iso8601("2023-04-01")

      assert {:ok, ^d} =
               Spectral.Codec.Date.decode(
                 :json,
                 Date,
                 {:type, :t, 0},
                 "2023-04-01",
                 :undefined,
                 :undefined,
                 :undefined
               )
    end

    test "decodes ISO 8601 charlist to Date for :string format" do
      {:ok, d} = Date.from_iso8601("2023-04-01")

      assert {:ok, ^d} =
               Spectral.Codec.Date.decode(
                 :string,
                 Date,
                 {:type, :t, 0},
                 ~c"2023-04-01",
                 :undefined,
                 :undefined,
                 :undefined
               )
    end

    test "decode returns type_mismatch with invalid_format reason for badly formatted string" do
      {:error, [error]} =
        Spectral.Codec.Date.decode(
          :json,
          Date,
          {:type, :t, 0},
          "not-a-date",
          :undefined,
          :undefined,
          :undefined
        )

      assert %Spectral.Error{type: :type_mismatch, context: %{reason: :invalid_format}} =
               Spectral.Error.from_erlang(error)
    end

    test "decode returns type_mismatch for non-string input" do
      {:error, [error]} =
        Spectral.Codec.Date.decode(
          :json,
          Date,
          {:type, :t, 0},
          12_345,
          :undefined,
          :undefined,
          :undefined
        )

      assert %Spectral.Error{type: :type_mismatch, context: ctx} =
               Spectral.Error.from_erlang(error)

      refute Map.has_key?(ctx, :reason)
    end

    test "encodes Date to binary string for :binary_string format" do
      {:ok, d} = Date.from_iso8601("2023-04-01")

      assert {:ok, "2023-04-01"} =
               Spectral.Codec.Date.encode(
                 :binary_string,
                 Date,
                 {:type, :t, 0},
                 d,
                 :undefined,
                 :undefined,
                 :undefined
               )
    end

    test "decodes ISO 8601 binary to Date for :binary_string format" do
      {:ok, d} = Date.from_iso8601("2023-04-01")

      assert {:ok, ^d} =
               Spectral.Codec.Date.decode(
                 :binary_string,
                 Date,
                 {:type, :t, 0},
                 "2023-04-01",
                 :undefined,
                 :undefined,
                 :undefined
               )
    end

    test "schema returns date format" do
      assert %{type: "string", format: "date"} =
               Spectral.Codec.Date.schema(
                 :json_schema,
                 Date,
                 {:type, :t, 0},
                 :undefined,
                 :undefined,
                 :undefined
               )
    end
  end
end
