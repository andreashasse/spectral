defmodule SpectralCodecTest do
  use ExUnit.Case, async: true

  describe "type_parameters forwarded to codec callbacks" do
    test "encode receives type_parameters as params" do
      assert {:ok, "user:abc123"} =
               Spectral.encode("abc123", PrefixedIdCodec, :user_id)
               |> then(fn {:ok, io} -> {:ok, IO.iodata_to_binary(io)} end)
    end

    test "encode uses correct params per type" do
      {:ok, user_encoded} =
        Spectral.encode("abc", PrefixedIdCodec, :user_id, :json, [:pre_encoded])

      {:ok, org_encoded} =
        Spectral.encode("abc", PrefixedIdCodec, :org_id, :json, [:pre_encoded])

      assert user_encoded == "user:abc"
      assert org_encoded == "org:abc"
    end

    test "decode receives type_parameters as params" do
      assert {:ok, "abc123"} =
               Spectral.decode("user:abc123", PrefixedIdCodec, :user_id, :json, [:pre_decoded])
    end

    test "decode uses correct params per type" do
      assert {:ok, "abc"} =
               Spectral.decode("org:abc", PrefixedIdCodec, :org_id, :json, [:pre_decoded])

      assert {:error, _} =
               Spectral.decode("user:abc", PrefixedIdCodec, :org_id, :json, [:pre_decoded])
    end

    test "schema receives type_parameters as params" do
      user_schema =
        Spectral.schema(PrefixedIdCodec, :user_id)
        |> IO.iodata_to_binary()
        |> :json.decode()

      assert user_schema["pattern"] == "^user:"

      org_schema =
        Spectral.schema(PrefixedIdCodec, :org_id)
        |> IO.iodata_to_binary()
        |> :json.decode()

      assert org_schema["pattern"] == "^org:"
    end

    test "type_parameters stored in type meta" do
      type_info = PrefixedIdCodec.__spectra_type_info__()
      {:ok, user_id_type} = Spectral.TypeInfo.find_type(type_info, :user_id, 0)

      assert :spectra_type.parameters(user_id_type) == "user:"
    end
  end
end
