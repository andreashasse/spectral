defmodule Spectral.OpenAPITest do
  use ExUnit.Case
  doctest Spectral.OpenAPI

  describe "endpoint/2" do
    test "creates a basic endpoint" do
      endpoint = Spectral.OpenAPI.endpoint(:get, "/users")

      assert endpoint.method == :get
      assert endpoint.path == "/users"
      assert endpoint.responses == %{}
      assert endpoint.parameters == []
    end

    test "supports different HTTP methods" do
      methods = [:get, :post, :put, :delete, :patch, :head, :options]

      for method <- methods do
        endpoint = Spectral.OpenAPI.endpoint(method, "/test")
        assert endpoint.method == method
      end
    end
  end

  describe "response builder pattern" do
    test "creates a basic response" do
      response = Spectral.OpenAPI.response(200, "Success")

      assert response.status_code == 200
      assert response.description == "Success"
    end

    test "adds body to response" do
      response =
        Spectral.OpenAPI.response(200, "User found")
        |> Spectral.OpenAPI.response_with_body(Person, :t)

      assert response.status_code == 200
      assert response.description == "User found"
      assert response.module == Person
      assert response.schema == :t
    end

    test "adds body with custom content type" do
      response =
        Spectral.OpenAPI.response(200, "Success")
        |> Spectral.OpenAPI.response_with_body(Person, :t, "application/xml")

      assert response.content_type == "application/xml"
      assert response.module == Person
      assert response.schema == :t
    end

    test "adds header to response" do
      response =
        Spectral.OpenAPI.response(200, "Success")
        |> Spectral.OpenAPI.response_with_header("X-Rate-Limit", Person, %{
          description: "Requests remaining",
          required: false,
          schema: :integer
        })

      assert Map.has_key?(response, :headers)
      assert Map.has_key?(response.headers, "X-Rate-Limit")
      header = response.headers["X-Rate-Limit"]
      assert header.description == "Requests remaining"
      assert header.required == false
      assert header.schema == :integer
      assert header.module == Person
    end

    test "chains multiple response modifications" do
      response =
        Spectral.OpenAPI.response(200, "Success")
        |> Spectral.OpenAPI.response_with_body(Person, :t)
        |> Spectral.OpenAPI.response_with_header("X-Custom", Person, %{
          schema: :string
        })

      assert response.module == Person
      assert response.schema == :t
      assert Map.has_key?(response.headers, "X-Custom")
    end
  end

  describe "add_response/2" do
    test "adds response to endpoint" do
      response =
        Spectral.OpenAPI.response(200, "Success")
        |> Spectral.OpenAPI.response_with_body(Person, :t)

      endpoint =
        Spectral.OpenAPI.endpoint(:get, "/users")
        |> Spectral.OpenAPI.add_response(response)

      assert Map.has_key?(endpoint.responses, 200)
      assert endpoint.responses[200].description == "Success"
      assert endpoint.responses[200].module == Person
      assert endpoint.responses[200].schema == :t
    end

    test "adds multiple responses to endpoint" do
      endpoint =
        Spectral.OpenAPI.endpoint(:get, "/users/{id}")
        |> Spectral.OpenAPI.add_response(
          Spectral.OpenAPI.response(200, "User found")
          |> Spectral.OpenAPI.response_with_body(Person, :t)
        )
        |> Spectral.OpenAPI.add_response(Spectral.OpenAPI.response(404, "User not found"))

      assert map_size(endpoint.responses) == 2
      assert Map.has_key?(endpoint.responses, 200)
      assert Map.has_key?(endpoint.responses, 404)
      assert endpoint.responses[404].description == "User not found"
    end
  end

  describe "with_request_body/3" do
    test "adds request body to endpoint" do
      endpoint =
        Spectral.OpenAPI.endpoint(:post, "/users")
        |> Spectral.OpenAPI.with_request_body(Person, :t)

      assert Map.has_key?(endpoint, :request_body)
      assert endpoint.request_body.module == Person
      assert endpoint.request_body.schema == :t
    end

    test "adds request body with custom content type" do
      endpoint =
        Spectral.OpenAPI.endpoint(:post, "/users")
        |> Spectral.OpenAPI.with_request_body(Person, :t, "application/xml")

      assert endpoint.request_body.content_type == "application/xml"
    end
  end

  describe "with_parameter/3" do
    test "adds path parameter to endpoint" do
      endpoint =
        Spectral.OpenAPI.endpoint(:get, "/users/{id}")
        |> Spectral.OpenAPI.with_parameter(Person, %{
          name: "id",
          in: :path,
          required: true,
          schema: :string
        })

      assert length(endpoint.parameters) == 1
      param = hd(endpoint.parameters)
      assert param.name == "id"
      assert param.in == :path
      assert param.required == true
      assert param.schema == :string
      assert param.module == Person
    end

    test "adds query parameter to endpoint" do
      endpoint =
        Spectral.OpenAPI.endpoint(:get, "/users")
        |> Spectral.OpenAPI.with_parameter(Person, %{
          name: "search",
          in: :query,
          required: false,
          schema: :string
        })

      param = hd(endpoint.parameters)
      assert param.name == "search"
      assert param.in == :query
      assert param.required == false
    end

    test "adds multiple parameters to endpoint" do
      endpoint =
        Spectral.OpenAPI.endpoint(:get, "/users")
        |> Spectral.OpenAPI.with_parameter(Person, %{
          name: "limit",
          in: :query,
          required: false,
          schema: :integer
        })
        |> Spectral.OpenAPI.with_parameter(Person, %{
          name: "offset",
          in: :query,
          required: false,
          schema: :integer
        })

      assert length(endpoint.parameters) == 2
    end
  end

  describe "endpoints_to_openapi/2" do
    test "generates basic OpenAPI spec" do
      metadata = %{title: "Test API", version: "1.0.0"}

      endpoints = [
        Spectral.OpenAPI.endpoint(:get, "/users")
        |> Spectral.OpenAPI.add_response(
          Spectral.OpenAPI.response(200, "List of users")
          |> Spectral.OpenAPI.response_with_body(Person, {:type, :t, 0})
        )
      ]

      {:ok, spec} = Spectral.OpenAPI.endpoints_to_openapi(metadata, endpoints)

      assert spec["openapi"] == "3.1.0"
      assert spec["info"]["title"] == "Test API"
      assert spec["info"]["version"] == "1.0.0"
      assert Map.has_key?(spec, "paths")
      assert Map.has_key?(spec["paths"], "/users")
    end

    test "generates spec with multiple endpoints" do
      metadata = %{title: "Test API", version: "1.0.0"}

      endpoints = [
        Spectral.OpenAPI.endpoint(:get, "/users")
        |> Spectral.OpenAPI.add_response(
          Spectral.OpenAPI.response(200, "Success")
          |> Spectral.OpenAPI.response_with_body(Person, {:type, :t, 0})
        ),
        Spectral.OpenAPI.endpoint(:post, "/users")
        |> Spectral.OpenAPI.with_request_body(Person, {:type, :t, 0})
        |> Spectral.OpenAPI.add_response(
          Spectral.OpenAPI.response(201, "Created")
          |> Spectral.OpenAPI.response_with_body(Person, {:type, :t, 0})
        )
      ]

      {:ok, spec} = Spectral.OpenAPI.endpoints_to_openapi(metadata, endpoints)

      assert Map.has_key?(spec["paths"], "/users")
      assert Map.has_key?(spec["paths"]["/users"], "get")
      assert Map.has_key?(spec["paths"]["/users"], "post")
    end
  end

  describe "complete workflow" do
    test "builds a complete REST API specification" do
      metadata = %{
        title: "User Management API",
        version: "1.0.0"
      }

      endpoints = [
        # GET /users - list users
        Spectral.OpenAPI.endpoint(:get, "/users")
        |> Spectral.OpenAPI.add_response(
          Spectral.OpenAPI.response(200, "List of users")
          |> Spectral.OpenAPI.response_with_body(Person, {:type, :t, 0})
        ),

        # GET /users/{id} - get specific user
        Spectral.OpenAPI.endpoint(:get, "/users/{id}")
        |> Spectral.OpenAPI.add_response(
          Spectral.OpenAPI.response(200, "User found")
          |> Spectral.OpenAPI.response_with_body(Person, {:type, :t, 0})
        )
        |> Spectral.OpenAPI.add_response(Spectral.OpenAPI.response(404, "User not found")),

        # POST /users - create user
        Spectral.OpenAPI.endpoint(:post, "/users")
        |> Spectral.OpenAPI.with_request_body(Person, {:type, :t, 0})
        |> Spectral.OpenAPI.add_response(
          Spectral.OpenAPI.response(201, "User created")
          |> Spectral.OpenAPI.response_with_body(Person, {:type, :t, 0})
        )
        |> Spectral.OpenAPI.add_response(Spectral.OpenAPI.response(400, "Invalid input"))
      ]

      {:ok, spec} = Spectral.OpenAPI.endpoints_to_openapi(metadata, endpoints)

      # Verify structure
      assert spec["openapi"] == "3.1.0"
      assert spec["info"]["title"] == "User Management API"
      assert map_size(spec["paths"]) == 2
      assert is_map_key(spec["paths"], "/users")
      assert is_map_key(spec["paths"], "/users/{id}")

      # Verify GET /users
      get_users = spec["paths"]["/users"]["get"]
      assert get_users["responses"]["200"]["description"] == "List of users"

      # Verify GET /users/{id}
      get_user = spec["paths"]["/users/{id}"]["get"]
      assert get_user["responses"]["200"]["description"] == "User found"
      assert get_user["responses"]["404"]["description"] == "User not found"

      # Verify POST /users
      post_users = spec["paths"]["/users"]["post"]
      assert is_map_key(post_users, "requestBody")
      assert post_users["responses"]["201"]["description"] == "User created"
      assert post_users["responses"]["400"]["description"] == "Invalid input"
    end
  end
end
