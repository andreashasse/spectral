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
  - `doc` - Optional documentation map with optional keys:
    - `:summary` - Short summary of the endpoint
    - `:description` - Longer description of the endpoint
    - `:operationId` - Unique string to identify the operation
    - `:tags` - List of tags for grouping endpoints
    - `:deprecated` - Whether the endpoint is deprecated (boolean)
    - `:externalDocs` - Map with `:url` (required) and `:description` (optional)

  ## Returns

  - `endpoint` - OpenAPI endpoint structure

  ## Example

      iex> endpoint = Spectral.OpenAPI.endpoint(:get, "/users/{id}", %{summary: "Get user by ID"})
      iex> endpoint.doc
      %{summary: "Get user by ID"}
  """
  @spec endpoint(atom(), binary(), %{
          optional(:summary) => binary(),
          optional(:description) => binary(),
          optional(:operationId) => binary(),
          optional(:tags) => [binary()],
          optional(:deprecated) => boolean(),
          optional(:externalDocs) => %{
            required(:url) => binary(),
            optional(:description) => binary()
          }
        }) :: dynamic()
  def endpoint(method, path, doc \\ %{}) do
    :spectra_openapi.endpoint(method, path, doc)
  end

  @doc """
  Creates a new OpenAPI endpoint definition using metadata from a `spectral/1` macro
  placed before a function definition.

  The function's metadata (set via `spectral summary: "...", description: "..."` before
  the corresponding `@spec`) is retrieved from the module's type info and used as the
  endpoint documentation.

  ## Parameters

  - `method` - HTTP method as an atom (`:get`, `:post`, `:put`, `:delete`, `:patch`, etc.)
  - `path` - URL path as a binary (e.g., `"/users/{id}"`)
  - `module` - The module containing the function with `spectral` metadata
  - `function_name` - The function name as an atom
  - `arity` - The function arity

  ## Returns

  - `endpoint` - OpenAPI endpoint structure with documentation from the function's metadata

  ## Example

      defmodule MyController do
        use Spectral

        spectral summary: "Get user", description: "Returns a user by ID"
        @spec get_user(map(), map()) :: map()
        def get_user(_conn, _params), do: %{}
      end

      endpoint = Spectral.OpenAPI.endpoint(:get, "/users/{id}", MyController, :get_user, 2)
  """
  @spec endpoint(atom(), binary(), module(), atom(), non_neg_integer()) :: dynamic()
  def endpoint(method, path, module, function_name, arity)
      when is_atom(method) and is_binary(path) and is_atom(module) and is_atom(function_name) and
             is_integer(arity) and arity >= 0 do
    doc = function_doc(module, function_name, arity)
    endpoint(method, path, doc)
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
    - `:deprecated` (optional) - Whether the header is deprecated (boolean)
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
  Adds a request body specification with additional options to an endpoint.

  ## Parameters

  - `endpoint` - The endpoint to modify
  - `module` - Module containing type definitions
  - `schema` - Schema reference (typically an atom like `:t`)
  - `opts` - Options map with optional keys:
    - `:content_type` - Content type override (e.g., `"application/xml"`; defaults to `"application/json"`)
    - `:description` - Description of the request body

  ## Returns

  - `endpoint` - Modified endpoint with request body

  ## Example

      endpoint = Spectral.OpenAPI.endpoint(:post, "/users")
        |> Spectral.OpenAPI.with_request_body(Person, :t, %{content_type: "application/xml"})
  """
  def with_request_body(endpoint, module, schema, opts) when is_map(opts) do
    :spectra_openapi.with_request_body(endpoint, module, schema, opts)
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
    - `:description` (optional) - Description of the parameter
    - `:deprecated` (optional) - Whether the parameter is deprecated (boolean)

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
    - `:title` - API title (required)
    - `:version` - API version (required)
    - `:summary` (optional) - Short summary of the API
    - `:description` (optional) - Longer description of the API
    - `:terms_of_service` (optional) - URL to the terms of service
    - `:contact` (optional) - Contact map with optional `:name`, `:url`, `:email`
    - `:license` (optional) - License map with required `:name` and optional `:url`, `:identifier`
    - `:servers` (optional) - List of server objects, each with required `:url` and optional `:description`
  - `endpoints` - List of endpoint definitions

  ## Returns

  - `{:ok, openapi_spec}` - Complete OpenAPI 3.0 specification as a map
  - `{:error, [%Spectral.Error{}]}` - List of errors if generation fails

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
  @spec endpoints_to_openapi(map(), [dynamic()]) ::
          {:ok, map()} | {:error, [Spectral.Error.t()]}
  def endpoints_to_openapi(metadata, endpoints) do
    metadata
    |> :spectra_openapi.endpoints_to_openapi(endpoints)
    |> convert_result()
  end

  # Private helper to convert Erlang results to Elixir
  defp convert_result({:ok, result}), do: {:ok, result}

  defp convert_result({:error, erlang_errors}) when is_list(erlang_errors) do
    {:error, Spectral.Error.from_erlang_list(erlang_errors)}
  end

  defp function_doc(module, function_name, arity) do
    Code.ensure_loaded!(module)

    unless function_exported?(module, :__spectra_type_info__, 0) do
      raise ArgumentError,
            "#{inspect(module)} does not use Spectral — add `use Spectral` to the module"
    end

    # credo:disable-for-next-line Credo.Check.Readability.WithSingleClause
    with {:ok, doc} <-
           Spectral.TypeInfo.get_function_doc(
             module.__spectra_type_info__(),
             function_name,
             arity
           ) do
      doc
    else
      {:error, :function_not_found} ->
        raise ArgumentError,
              "#{inspect(module)}.#{function_name}/#{arity} has no @spec — add a @spec before using spectral/1 to annotate it"

      {:error, :no_doc_found} ->
        raise ArgumentError,
              "#{inspect(module)}.#{function_name}/#{arity} has no spectral/1 annotation — add `spectral summary: \"...\"` before its @spec"
    end
  end
end
