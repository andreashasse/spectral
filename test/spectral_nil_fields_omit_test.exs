defmodule Spectral.NilFieldsOmitTest do
  # Reads the :spectra application env, so it must not run alongside tests that change it.
  use ExUnit.Case, async: false

  test "pre_encoded leaves out nil fields when nil_fields is not set" do
    value = %NilFieldsModule{
      name: "root",
      child: %NilFieldsModule.Item{label: "child"},
      items: [%NilFieldsModule.Item{label: "a"}],
      active: true
    }

    assert {:ok,
            %{
              "name" => "root",
              "child" => %{"label" => "child"},
              "items" => [%{"label" => "a"}],
              "active" => true
            } = term} = Spectral.encode(value, NilFieldsModule, :t, :json, [:pre_encoded])

    refute Map.has_key?(term, "note")
  end
end
