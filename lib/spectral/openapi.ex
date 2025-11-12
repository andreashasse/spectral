defmodule Spectral.OpenAPI do
  @moduledoc """
  Elixir wrapper for spectra OpenAPI specification generation.

  This module provides idiomatic Elixir functions for generating OpenAPI 3.0
  specifications from Elixir type definitions using spectra.

  ## Response Builder Pattern

  Responses are built using a fluent API:

      response = Spectral.OpenAPI.response(200, "Success")
        |> Spectral.OpenAPI.response_with_body(Person, :t)
        |> Spectral.OpenAPI.response_with_header("X-Rate-Limit", RateLimit, :t, %{
          description: "Remaining requests",
          required: false
        })

      endpoint = Spectral.OpenAPI.endpoint(:get, "/users/{id}")
        |> Spectral.OpenAPI.add_response(response)
  """

  @doc """
  Creates a new OpenAPI endpoint definition.

  ## Parameters

  - `method` - HTTP method as an atom (`:get`, `:post`, `:put`, `:delete`, `:patch`, etc.)
  - `path` - URL path as a binary (e.g., `"/users/{id}"`)

  ## Returns

  - `endpoint` - OpenAPI endpoint structure

  ## Example

      endpoint = Spectral.OpenAPI.endpoint(:get, "/users/{id}")
  """
  def endpoint(method, path) do
    :spectra_openapi.endpoint(method, path)
  end

  @doc """
  Creates a response builder.

  This creates a response specification that can be further configured with
  `response_with_body/3-4` and `response_with_header/4` before being added
  to an endpoint with `add_response/2`.

  ## Parameters

  - `status_code` - HTTP status code (e.g., `200`, `404`, `500`)
  - `description` - Human-readable description of the response

  ## Returns

  - `response` - Response builder structure

  ## Example

      response = Spectral.OpenAPI.response(200, "User found successfully")
  """
  def response(status_code, description) do
    :spectra_openapi.response(status_code, description)
  end

  @doc """
  Adds a response body to a response builder.

  ## Parameters

  - `response` - Response builder from `response/2`
  - `module` - Module containing the type definition
  - `schema` - Schema reference (typically an atom like `:t`)

  ## Returns

  - `response` - Updated response builder with body schema

  ## Example

      response = Spectral.OpenAPI.response(200, "Success")
        |> Spectral.OpenAPI.response_with_body(Person, :t)
  """
  def response_with_body(response, module, schema) do
    :spectra_openapi.response_with_body(response, module, schema)
  end

  @doc """
  Adds a response body with custom content type to a response builder.

  ## Parameters

  - `response` - Response builder from `response/2`
  - `module` - Module containing the type definition
  - `schema` - Schema reference (typically an atom like `:t`)
  - `content_type` - Content type (e.g., `"application/json"`, `"application/xml"`)

  ## Returns

  - `response` - Updated response builder with body schema and content type

  ## Example

      response = Spectral.OpenAPI.response(200, "Success")
        |> Spectral.OpenAPI.response_with_body(Person, :t, "application/xml")
  """
  def response_with_body(response, module, schema, content_type) do
    :spectra_openapi.response_with_body(response, module, schema, content_type)
  end

  @doc """
  Adds a header to a response builder.

  ## Parameters

  - `response` - Response builder from `response/2`
  - `header_name` - Name of the response header (e.g., `"X-Rate-Limit"`)
  - `module` - Module containing the type definition for the header value
  - `header_spec` - Header specification map with keys:
    - `:description` (optional) - Description of the header
    - `:required` (optional) - Whether the header is required (default: false)
    - `:schema` - Schema for the header value

  ## Returns

  - `response` - Updated response builder with header added

  ## Example

      response = Spectral.OpenAPI.response(200, "Success")
        |> Spectral.OpenAPI.response_with_header("X-Rate-Limit", RateLimit, :t, %{
          description: "Requests remaining",
          required: false,
          schema: :integer
        })
  """
  def response_with_header(response, header_name, module, header_spec) do
    :spectra_openapi.response_with_header(response, header_name, module, header_spec)
  end

  @doc """
  Adds a complete response specification to an endpoint.

  This function adds a response that was built using the response builder pattern.

  ## Parameters

  - `endpoint` - The endpoint to add the response to
  - `response` - Response specification built with `response/2` and related functions

  ## Returns

  - `endpoint` - Updated endpoint with the response added

  ## Example

      response = Spectral.OpenAPI.response(200, "User found")
        |> Spectral.OpenAPI.response_with_body(Person, :t)

      endpoint = Spectral.OpenAPI.endpoint(:get, "/users/{id}")
        |> Spectral.OpenAPI.add_response(response)
  """
  def add_response(endpoint, response) do
    :spectra_openapi.add_response(endpoint, response)
  end

  @doc """
  Adds a request body specification to an endpoint.

  ## Parameters

  - `endpoint` - The endpoint to modify
  - `module` - Module containing type definitions
  - `schema` - Schema reference (typically an atom like `:t`)

  ## Returns

  - `endpoint` - Modified endpoint with request body

  ## Example

      endpoint = Spectral.OpenAPI.endpoint(:post, "/users")
        |> Spectral.OpenAPI.with_request_body(Person, :t)
  """
  def with_request_body(endpoint, module, schema) do
    :spectra_openapi.with_request_body(endpoint, module, schema)
  end

  @doc """
  Adds a request body specification with custom content type to an endpoint.

  ## Parameters

  - `endpoint` - The endpoint to modify
  - `module` - Module containing type definitions
  - `schema` - Schema reference (typically an atom like `:t`)
  - `content_type` - Content type (e.g., `"application/json"`, `"application/xml"`)

  ## Returns

  - `endpoint` - Modified endpoint with request body

  ## Example

      endpoint = Spectral.OpenAPI.endpoint(:post, "/users")
        |> Spectral.OpenAPI.with_request_body(Person, :t, "application/xml")
  """
  def with_request_body(endpoint, module, schema, content_type) do
    :spectra_openapi.with_request_body(endpoint, module, schema, content_type)
  end

  @doc """
  Adds a parameter to an endpoint.

  Parameters can be in the path, query string, headers, or cookies.

  ## Parameters

  - `endpoint` - The endpoint to modify
  - `module` - Module containing the type definition for the parameter
  - `parameter_spec` - Parameter specification map with keys:
    - `:name` - Parameter name
    - `:in` - Location (`:path`, `:query`, `:header`, `:cookie`)
    - `:required` - Whether the parameter is required
    - `:schema` - Schema for the parameter value

  ## Returns

  - `endpoint` - Modified endpoint with parameter added

  ## Example

      endpoint = Spectral.OpenAPI.endpoint(:get, "/users/{id}")
        |> Spectral.OpenAPI.with_parameter(User, %{
          name: "id",
          in: :path,
          required: true,
          schema: :string
        })
  """
  def with_parameter(endpoint, module, parameter_spec) do
    :spectra_openapi.with_parameter(endpoint, module, parameter_spec)
  end

  @doc """
  Converts a list of endpoints to a complete OpenAPI specification.

  ## Parameters

  - `metadata` - OpenAPI metadata map with keys:
    - `:title` - API title
    - `:version` - API version
  - `endpoints` - List of endpoint definitions

  ## Returns

  - `{:ok, openapi_spec}` - Complete OpenAPI 3.0 specification as iodata
  - `{:error, errors}` - List of errors if generation fails

  ## Example

      metadata = %{title: "My API", version: "1.0.0"}
      endpoints = [
        Spectral.OpenAPI.endpoint(:get, "/users/{id}")
        |> Spectral.OpenAPI.add_response(
          Spectral.OpenAPI.response(200, "User found")
          |> Spectral.OpenAPI.response_with_body(Person, :t)
        )
      ]

      {:ok, openapi_spec} = Spectral.OpenAPI.endpoints_to_openapi(metadata, endpoints)
  """
  def endpoints_to_openapi(metadata, endpoints) do
    :spectra_openapi.endpoints_to_openapi(metadata, endpoints)
  end
end
