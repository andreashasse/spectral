defmodule SpectralNestedDocTest do
  # Doc annotations (title, description, deprecated, examples) survive inlining
  # into another schema (spectra 0.14.0). Before 0.14.0 only the type schema
  # generation was entered with kept them.
  use ExUnit.Case, async: true

  defp schema(module, type) do
    module |> Spectral.schema(type) |> IO.iodata_to_binary() |> Jason.decode!()
  end

  defp properties(module, type), do: schema(module, type)["properties"]

  describe "annotations on inlined types" do
    test "a remote annotated type keeps its metadata as a map field value" do
      assert %{
               "type" => "string",
               "title" => "Payer",
               "description" => "Account charged",
               "deprecated" => true
             } = properties(NestedDocModule, :request)["payer"]
    end

    test "a local annotated type keeps title, description and examples as a map field value" do
      assert %{
               "type" => "integer",
               "title" => "Amount",
               "description" => "Amount in cents",
               "examples" => [1500]
             } = properties(NestedDocModule, :request)["amount"]
    end

    test "list and non-empty list elements keep their metadata" do
      props = properties(NestedDocModule, :request)

      assert %{"title" => "Tag", "description" => "A short tag"} = props["tags"]["items"]
      assert %{"title" => "Tag", "description" => "A short tag"} = props["more_tags"]["items"]
      assert props["more_tags"]["minItems"] == 1
    end

    test "a union branch keeps its metadata" do
      assert %{"anyOf" => branches} = properties(NestedDocModule, :request)["note"]

      assert %{"type" => "string", "title" => "Tag", "description" => "A short tag"} in branches
      assert %{"type" => "integer"} in branches
    end

    test "an optional map value keeps its metadata" do
      assert %{"title" => "Tag", "description" => "A short tag"} =
               properties(NestedDocModule, :optional_map)["tag"]
    end

    test "struct fields keep their metadata" do
      props = properties(NestedDocModule, :t)

      assert %{"title" => "Amount", "examples" => [1500]} = props["amount"]
      assert %{"title" => "Tag"} = props["tag"]
    end
  end

  describe "annotation merging through an alias" do
    test "the annotation nearest the use site wins and other keys are kept from both" do
      assert %{"title" => "Label", "description" => "A short tag"} =
               properties(NestedDocModule, :labelled)["label"]
    end
  end

  describe "example validation at inlined positions" do
    test "an example that does not encode as its own type is rejected when inlined" do
      assert_raise ArgumentError,
                   ~s{invalid example "not an integer" for type count/0 (schema)},
                   fn -> Spectral.schema(NestedDocBadExampleModule, :wrapper) end
    end
  end
end
