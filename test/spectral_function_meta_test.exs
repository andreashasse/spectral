defmodule Spectral.FunctionMetaTest do
  use ExUnit.Case, async: true

  describe "spectral macro before functions" do
    test "function doc is stored in type_info when spectral precedes @spec" do
      type_info = EndpointHandler.__spectra_type_info__()

      assert {:ok, doc} = Spectral.TypeInfo.get_function_doc(type_info, :get, 2)
      assert doc[:summary] == "Get resource"
      assert doc[:description] == "Returns a resource by ID"
    end

    test "function doc supports deprecated flag" do
      type_info = EndpointHandler.__spectra_type_info__()

      assert {:ok, doc} = Spectral.TypeInfo.get_function_doc(type_info, :create, 2)
      assert doc[:summary] == "Create resource"
      assert doc[:deprecated] == false
    end

    test "type metadata still works alongside function metadata" do
      type_info = EndpointHandler.__spectra_type_info__()

      assert {:ok, type} = Spectral.TypeInfo.find_type(type_info, :t, 0)
      meta = :spectra_type.get_meta(type)
      assert meta[:doc][:title] == "EndpointHandler"
      assert meta[:doc][:description] == "A handler type"
    end

    test "get_function_doc returns no_doc_found for function with @spec but no spectral annotation" do
      type_info = EndpointHandler.__spectra_type_info__()

      assert {:error, :no_doc_found} =
               Spectral.TypeInfo.get_function_doc(type_info, :list, 1)
    end

    test "get_function_doc returns function_not_found for unknown function" do
      type_info = EndpointHandler.__spectra_type_info__()

      assert {:error, :function_not_found} =
               Spectral.TypeInfo.get_function_doc(type_info, :nonexistent, 0)
    end
  end

  describe "multiple @spec clauses and multiple @spectral annotations" do
    test "single @spectral before guarded @spec overloads attaches doc to the function" do
      type_info = MultiSpectralHandler.__spectra_type_info__()

      assert {:ok, doc} = Spectral.TypeInfo.get_function_doc(type_info, :process, 1)
      assert doc[:summary] == "Process item"
      assert doc[:description] == "Handles both integers and binaries"
    end

    test "two @spectral annotations before the same @spec — last annotation wins" do
      type_info = MultiSpectralHandler.__spectra_type_info__()

      assert {:ok, doc} = Spectral.TypeInfo.get_function_doc(type_info, :update, 1)
      assert doc[:summary] == "Second annotation wins"
    end
  end

  describe "endpoint/5 using function metadata" do
    test "creates endpoint with doc from function metadata" do
      endpoint =
        Spectral.OpenAPI.endpoint(:get, "/resources/{id}", EndpointHandler, :get, 2)

      assert endpoint.method == :get
      assert endpoint.path == "/resources/{id}"
      assert endpoint.doc[:summary] == "Get resource"
      assert endpoint.doc[:description] == "Returns a resource by ID"
    end

    test "creates endpoint with empty doc when function has no spectral annotation" do
      endpoint = Spectral.OpenAPI.endpoint(:get, "/persons", Person, :testdata, 0)

      assert endpoint.doc == %{}
    end

    test "endpoint doc integrates into the full openapi spec" do
      metadata = %{title: "Test API", version: "1.0.0"}

      endpoints = [
        Spectral.OpenAPI.endpoint(:get, "/resources/{id}", EndpointHandler, :get, 2)
        |> Spectral.OpenAPI.add_response(
          Spectral.OpenAPI.response(200, "Success")
          |> Spectral.OpenAPI.response_with_body(EndpointHandler, {:type, :t, 0})
        )
      ]

      {:ok, spec} = Spectral.OpenAPI.endpoints_to_openapi(metadata, endpoints)

      get_op = spec["paths"]["/resources/{id}"]["get"]
      assert get_op["summary"] == "Get resource"
      assert get_op["description"] == "Returns a resource by ID"
    end
  end
end
