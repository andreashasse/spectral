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
end
