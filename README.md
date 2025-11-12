# Spectral

An Elixir wrapper for the Erlang [spectra](https://github.com/andreashasse/spectra) library. Spectral provides type-safe data serialization and deserialization for all Elixir types that can be converted to those types. Currently the focus is on JSON.

- **Type-safe conversion**: Convert typed Elixir values to/from external formats such as JSON, ensuring data conforms to the type specification
- **Detailed errors**: Get error messages with location information when validation fails
- **Support for complex scenarios**: Handles unions, structs, atoms, nested structures, and more

## Installation

Add `spectral` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:spectral, "~> 0.1.0"}
  ]
end
```
### Basic Usage

Here's how to use Spectral for JSON serialization and deserialization:

```elixir
defmodule Person do
  defmodule Address do
    defstruct [:street, :city]

    @type t :: %Address{
            street: String.t(),
            city: String.t()
          }
  end

  defstruct [:name, :age, :address]

  @type t :: %Person{
          name: String.t(),
          age: non_neg_integer() | nil,
          address: Address.t() | nil
        }
end

# Encode a struct to JSON
person = %Person{
  name: "Alice",
  age: 30,
  address: %Person.Address{
    street: "Ystader Straße",
    city: "Berlin"
  }
}

{:ok, json_iodata} = Spectral.encode(:json, Person, :t, person)
json = IO.iodata_to_binary(json_iodata)
# => "{\"address\":{\"city\":\"Berlin\",\"street\":\"Ystader Straße\"},\"age\":30,\"name\":\"Alice\"}"

# Decode JSON to a struct
json_string = ~s({"name":"Alice","age":30,"address":{"street":"Ystader Straße","city":"Berlin"}})
{:ok, decoded_person} = Spectral.decode(:json, Person, :t, json_string)
# => {:ok, %Person{name: "Alice", age: 30, address: %Person.Address{street: "Ystader Straße", city: "Berlin"}}}

# Generate a JSON schema
{:ok, schema_iodata} = Spectral.schema(:json_schema, Person, :t)
schema = IO.iodata_to_binary(schema_iodata)
```

### Nil Value Handling

Spectral automatically omits `nil` values from JSON output for optional struct fields:

```elixir
# Only required fields
person = %Person{name: "Alice"}
{:ok, json_iodata} = Spectral.encode(:json, Person, :t, person)
IO.iodata_to_binary(json_iodata)
# => "{\"name\":\"Alice\"}"  (age and address are omitted)

# When decoding, missing fields become nil in structs and records
{:ok, decoded} = Spectral.decode(:json, Person, :t, ~s({"name":"Alice"}))
# => {:ok, %Person{name: "Alice", age: nil, address: nil}}
```

### Data Serialization API

The main functions for JSON serialization and deserialization:

```elixir
Spectral.encode(format, module, type_ref, value) ::
    {:ok, iodata()} | {:error, [error()]}

Spectral.decode(format, module, type_ref, data) ::
    {:ok, value} | {:error, [error()]}
```

**Parameters:**
- `format` - The data format: `:json`, `:binary_string`, or `:string`
- `module` - The module where the type is defined (e.g., `Person`)
- `type_ref` - The type reference, typically an atom like `:t` for the `@type t` definition
- `value` / `data` - The Elixir value to encode or the binary data to decode

### Schema API

Generate schemas from your type definitions:

```elixir
Spectral.schema(format, module, type_ref) ::
    {:ok, iodata()} | {:error, [error()]}
```

**Parameters:**
- `format` - Currently supports `:json_schema`
- `module` - The module where the type is defined
- `type_ref` - The type reference

## OpenAPI Specification

Spectral can generate complete [OpenAPI 3.0](https://spec.openapis.org/oas/v3.0.0) specifications for your REST APIs. This provides interactive documentation, client generation, and API testing tools.

### OpenAPI Builder API

The API uses a fluent builder pattern for constructing endpoints and responses. While experimental and subject to change, it's designed to be used by web framework developers.

#### Building Responses

Responses are constructed using a builder pattern:

```elixir
# Create a response
response = Spectral.OpenAPI.response(200, "User found successfully")

# Add a body to the response
response_with_body = Spectral.OpenAPI.response(200, "User found")
  |> Spectral.OpenAPI.response_with_body(Person, :t)

# Add headers to a response
response_with_headers = Spectral.OpenAPI.response(200, "Success")
  |> Spectral.OpenAPI.response_with_body(Person, :t)
  |> Spectral.OpenAPI.response_with_header("X-Rate-Limit", RateLimit, :t, %{
    description: "Requests remaining",
    required: false,
    schema: :integer
  })
```

#### Building Endpoints

Endpoints are built by combining the endpoint definition with responses, request bodies, and parameters:

```elixir
# Create an endpoint and add a response
endpoint = Spectral.OpenAPI.endpoint(:get, "/users/{id}")
  |> Spectral.OpenAPI.add_response(
    Spectral.OpenAPI.response(200, "User found")
    |> Spectral.OpenAPI.response_with_body(Person, :t)
  )
  |> Spectral.OpenAPI.add_response(
    Spectral.OpenAPI.response(404, "User not found")
  )

# Add request body (for POST, PUT, PATCH)
create_endpoint = Spectral.OpenAPI.endpoint(:post, "/users")
  |> Spectral.OpenAPI.with_request_body(Person, :t)
  |> Spectral.OpenAPI.add_response(
    Spectral.OpenAPI.response(201, "User created")
    |> Spectral.OpenAPI.response_with_body(Person, :t)
  )

# Add parameters
search_endpoint = Spectral.OpenAPI.endpoint(:get, "/users")
  |> Spectral.OpenAPI.with_parameter(User, %{
    name: "search",
    in: :query,
    required: false,
    schema: :string
  })
  |> Spectral.OpenAPI.add_response(
    Spectral.OpenAPI.response(200, "Users found")
    |> Spectral.OpenAPI.response_with_body(UserList, :t)
  )
```

#### Generating the OpenAPI Specification

Combine all endpoints into a complete OpenAPI spec:

```elixir
metadata = %{
  title: "My API",
  version: "1.0.0"
}

endpoints = [
  Spectral.OpenAPI.endpoint(:get, "/users/{id}")
  |> Spectral.OpenAPI.add_response(
    Spectral.OpenAPI.response(200, "User found")
    |> Spectral.OpenAPI.response_with_body(Person, :t)
  )
  |> Spectral.OpenAPI.with_parameter(User, %{
    name: "id",
    in: :path,
    required: true,
    schema: :string
  })
]

{:ok, openapi_spec} = Spectral.OpenAPI.endpoints_to_openapi(metadata, endpoints)
IO.puts(IO.iodata_to_binary(openapi_spec))
```

## Requirements

- **Elixir**: ~> 1.19
- **Compilation**: Modules must be compiled with `debug_info` for Spectral to extract type information. This is enabled by default in Mix projects.

## Error Handling

Spectral uses Elixir-style error tuples for validation errors:

### Validation Errors

Data validation errors are returned as `{:error, [error]}` tuples. These occur when input data doesn't match the expected type during encoding/decoding.

```elixir
bad_json = ~s({"name":"Alice","age":"not a number"})
{:error, errors} = Spectral.decode(:json, Person, :t, bad_json)
# Returns a list of error structures with location and type information
```

Error structures contain:
- `location` - Path showing where the error occurred
- `type` - Error type: `:type_mismatch`, `:no_match`, `:missing_data`, etc.
- `ctx` - Context information about the error

### Configuration Errors

Configuration and structural errors raise exceptions. These occur when:
- Module not found or not loaded
- Type not found in module
- Unsupported type used (e.g., `pid()`, `port()`, `tuple()`)

These errors indicate a problem with your application's configuration or type definitions, not with the data being processed.

## Special Handling

### `nil` Values

In Elixir structs, `nil` values are handled specially:
- When encoding to JSON, struct fields with `nil` values are omitted from the output if the type includes `nil` as a valid value
- When decoding from JSON, missing fields become `nil` if the type specification allows it

Example:
```elixir
@type t :: %Person{
  name: String.t(),
  age: non_neg_integer() | nil  # nil is allowed
}
```

### `term()` and `any()`

When using types with `term()` or `any()`, Spectral will not reject any data, which means it can return data that may not be valid JSON.

### Unsupported Types

For JSON serialization and schema generation, the following Erlang/Elixir types are not supported:
- `pid()`, `port()`, `reference()` - Cannot be serialized to JSON
- `tuple()` (generic tuples without specific structure)
- Function types - Cannot be serialized

## Related Projects

- **[spectra](https://github.com/andreashasse/spectra)** - The underlying Erlang library that powers Spectral

## Development Status

This library is under active development. APIs may change in future versions.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

See LICENSE.md for details.
