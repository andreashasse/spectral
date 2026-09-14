defmodule SpectralNestedDocTest do
  # Doc annotations (title, description, deprecated, examples) survive inlining
  # into another schema (spectra 0.14.0). Before 0.14.0 the annotations were
  # kept only on the type that schema generation was entered with.
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

  describe "examples_function at inlined positions" do
    test "the function is called once per position the type is inlined into" do
      before = NestedDocModule.counted_examples_calls()
      props = properties(NestedDocModule, :two_counted)

      assert NestedDocModule.counted_examples_calls() - before == 2
      assert %{"title" => "Counted", "examples" => [7]} = props["first"]
      assert %{"title" => "Counted", "examples" => [7]} = props["second"]
    end
  end

  describe "annotations in OpenAPI output" do
    test "a response body schema carries the annotations of its nested types" do
      endpoint =
        Spectral.OpenAPI.endpoint(:get, "/payments")
        |> Spectral.OpenAPI.add_response(
          Spectral.OpenAPI.response(200, "OK")
          |> Spectral.OpenAPI.response_with_body(NestedDocModule, {:type, :t, 0})
        )

      {:ok, json} =
        Spectral.OpenAPI.endpoints_to_openapi(%{title: "API", version: "1.0"}, [endpoint])

      spec = json |> IO.iodata_to_binary() |> Jason.decode!()

      assert %{"$ref" => "#/components/schemas/NestedDocModule"} =
               spec["paths"]["/payments"]["get"]["responses"]["200"]["content"][
                 "application/json"
               ]["schema"]

      props = spec["components"]["schemas"]["NestedDocModule"]["properties"]

      assert %{"title" => "Amount", "description" => "Amount in cents"} = props["amount"]
      assert %{"title" => "Tag", "description" => "A short tag"} = props["tag"]
    end
  end
end
