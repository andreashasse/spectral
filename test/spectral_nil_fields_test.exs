defmodule Spectral.NilFieldsTest do
  # Changes the :spectra application env, so it must not run alongside other tests.
  use ExUnit.Case, async: false

  setup do
    previous = Application.fetch_env(:spectra, :nil_fields)
    Application.put_env(:spectra, :nil_fields, :null)

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:spectra, :nil_fields, value)
        :error -> Application.delete_env(:spectra, :nil_fields)
      end
    end)
  end

  test "encodes a nil field as null and marks it required in the schema" do
    {:ok, json} = Spectral.encode(%Person{name: "Alice"}, Person, :t, :json)
    assert %{"name" => "Alice", "age" => :null} = :json.decode(IO.iodata_to_binary(json))

    schema = Spectral.schema(Person, :t) |> IO.iodata_to_binary() |> :json.decode()
    assert "age" in schema["required"]
    assert %{"type" => ["integer", "null"]} = schema["properties"]["age"]
  end

  describe "pre_encoded" do
    test "writes nil, not the atom :null, for nil fields at any depth" do
      {:ok, term} = Spectral.encode(nested_value(), NilFieldsModule, :t, :json, [:pre_encoded])

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

      assert JSON.encode!(term) =~ ~s("note":null)
      assert JSON.encode!(term) =~ ~s("count":null)
    end

    test "matches the iodata encoding" do
      {:ok, term} = Spectral.encode(nested_value(), NilFieldsModule, :t, :json, [:pre_encoded])
      {:ok, json} = Spectral.encode(nested_value(), NilFieldsModule, :t, :json)

      assert JSON.decode!(JSON.encode!(term)) == JSON.decode!(IO.iodata_to_binary(json))
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
