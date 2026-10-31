defmodule Spectral.NilFieldsOptionTest do
  # Changes the :spectra application env, so it must not run alongside other tests.
  use ExUnit.Case, async: false

  setup do
    previous = Application.fetch_env(:spectra, :nil_fields)
    Application.delete_env(:spectra, :nil_fields)

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:spectra, :nil_fields, value)
        :error -> Application.delete_env(:spectra, :nil_fields)
      end
    end)
  end

  describe "nil_fields: :null without a global setting" do
    test "writes nil fields as null in iodata, at any depth" do
      {:ok, json} = Spectral.encode(nested_value(), NilFieldsModule, :t, :json, nil_fields: :null)
      binary = IO.iodata_to_binary(json)

      assert binary =~ ~s("note":null)

      assert JSON.decode!(binary) == %{
               "name" => "root",
               "note" => nil,
               "child" => %{"label" => "child", "count" => nil},
               "items" => [
                 %{"label" => "a", "count" => nil},
                 %{"label" => "b", "count" => 2}
               ],
               "active" => false
             }
    end

    test "writes nil, not the atom :null, with pre_encoded" do
      {:ok, term} =
        Spectral.encode(nested_value(), NilFieldsModule, :t, :json, [
          :pre_encoded,
          nil_fields: :null
        ])

      assert term == %{
               "name" => "root",
               "note" => nil,
               "child" => %{"label" => "child", "count" => nil},
               "items" => [
                 %{"label" => "a", "count" => nil},
                 %{"label" => "b", "count" => 2}
               ],
               "active" => false
             }
    end

    test "encode! accepts the option" do
      json = Spectral.encode!(nested_value(), NilFieldsModule, :t, :json, nil_fields: :null)
      assert IO.iodata_to_binary(json) =~ ~s("note":null)
    end

    test "does not change the schema" do
      schema = Spectral.schema(NilFieldsModule, :t) |> IO.iodata_to_binary() |> JSON.decode!()
      refute "note" in schema["required"]
      assert %{"type" => ["string", "null"]} = schema["properties"]["note"]
    end
  end

  test "nil_fields: :omit leaves nil fields out" do
    {:ok, term} =
      Spectral.encode(nested_value(), NilFieldsModule, :t, :json, [
        :pre_encoded,
        nil_fields: :omit
      ])

    refute Map.has_key?(term, "note")
    assert term["child"] == %{"label" => "child"}
  end

  test "without the option nil fields are left out" do
    {:ok, json} = Spectral.encode(nested_value(), NilFieldsModule, :t, :json)
    refute IO.iodata_to_binary(json) =~ "null"
  end

  test "nil_fields: :null raises ArgumentError when the global setting is :omit" do
    Application.put_env(:spectra, :nil_fields, :omit)

    assert_raise ArgumentError, ~r/nil_fields setting is omit/, fn ->
      Spectral.encode(nested_value(), NilFieldsModule, :t, :json, nil_fields: :null)
    end
  end

  test "nil_fields: :omit raises ArgumentError when the global setting is :null" do
    Application.put_env(:spectra, :nil_fields, :null)

    assert_raise ArgumentError, ~r/nil_fields setting is null/, fn ->
      Spectral.encode(nested_value(), NilFieldsModule, :t, :json, nil_fields: :omit)
    end
  end

  defp nested_value do
    %NilFieldsModule{
      name: "root",
      note: nil,
      child: %NilFieldsModule.Item{label: "child", count: nil},
      items: [
        %NilFieldsModule.Item{label: "a", count: nil},
        %NilFieldsModule.Item{label: "b", count: 2}
      ],
      active: false
    }
  end
end
