# Spectral

Spectral provides type-safe data serialization and deserialization for Elixir types. Currently the focus is on JSON.

- **Type-safe conversion**: Convert typed Elixir values to/from external formats such as JSON, ensuring data conforms to the type specification
- **Detailed errors**: Get error messages with location information when validation fails
- **Support for complex scenarios**: Handles unions, structs, atoms, nested structures, and more

## Installation

Add `spectral` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:spectral, "~> 0.1.1"}
  ]
end
```
## Usage

Here's how to use Spectral for JSON serialization and deserialization:

**Note:** Spectral reads type information from compiled beam files, so modules must be defined in files (not in IEx).

```elixir
# lib/person.ex
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
```

```elixir
# Encode a struct to JSON
person = %Person{
  name: "Alice",
  age: 30,
  address: %Person.Address{
    street: "Ystader Straße",
    city: "Berlin"
  }
}

with {:ok, json_iodata} <- Spectral.encode(person, Person, :t) do
  IO.iodata_to_binary(json_iodata)
  # Returns: "{\"address\":{\"city\":\"Berlin\",\"street\":\"Ystader Straße\"},\"age\":30,\"name\":\"Alice\"}"
end

# Decode JSON to a struct 
json_string = ~s({"name":"Alice","age":30,"address":{"street":"Ystader Straße","city":"Berlin"}})
{:ok, person} = Spectral.decode(json_string, Person, :t)

# Generate a JSON schema 
with {:ok, schema_iodata} <- Spectral.schema(Person, :t) do
  IO.iodata_to_binary(schema_iodata)
end
```

### Bang Functions

For convenience, Spectral provides bang versions (`!`) of all main functions that raise exceptions instead of returning error tuples:

```elixir
json =
  person
  |> Spectral.encode!(Person, :t)
  |> IO.iodata_to_binary()

person =
  json_string
  |> Spectral.decode!(Person, :t)

schema =
  Person
  |> Spectral.schema!(:t)
  |> IO.iodata_to_binary()
```

Use bang functions when you want exceptions instead of explicit error handling.

### Nil Value Handling

Spectral automatically omits `nil` values from JSON output for optional struct fields:

```elixir
# Only required fields
person = %Person{name: "Alice"}

with {:ok, json_iodata} <- Spectral.encode(person, Person, :t) do
  IO.iodata_to_binary(json_iodata)
  # Returns: "{\"name\":\"Alice\"}" (age and address are omitted)
end

# When decoding, missing fields become nil in structs
Spectral.decode(~s({"name":"Alice"}), Person, :t)
# Returns: {:ok, %Person{name: "Alice", age: nil, address: nil}}
```

### Data Serialization API

The main functions for JSON serialization and deserialization (pipe-friendly):

```elixir
# Regular versions (return tuples)
Spectral.encode(data, module, type_ref, format \\ :json) ::
    {:ok, iodata()} | {:error, [%Spectral.Error{}]}

Spectral.encode!(data, module, type_ref, format \\ :json) :: iodata()

Spectral.decode(data, module, type_ref, format \\ :json) ::
    {:ok, term()} | {:error, [%Spectral.Error{}]}

Spectral.decode!(data, module, type_ref, format \\ :json) :: term()
```

**Parameters:**
- `data` - The data to encode/decode (Elixir value for encode, binary/string for decode)
- `module` - The module where the type is defined (e.g., `Person`)
- `type_ref` - The type reference, typically an atom like `:t` for the `@type t` definition
- `format` - (optional) The data format: `:json` (default), `:binary_string`, or `:string`

### Schema API

Generate schemas from your type definitions:

```elixir
Spectral.schema(module, type_ref, format \\ :json_schema) ::
    {:ok, iodata()} | {:error, [%Spectral.Error{}]}

Spectral.schema!(module, type_ref, format \\ :json_schema) :: iodata()
```

**Parameters:**
- `module` - The module where the type is defined
- `type_ref` - The type reference
- `format` - (optional) Schema format, currently supports `:json_schema` (default)

## OpenAPI Specification

Spectral can generate complete [OpenAPI 3.0](https://spec.openapis.org/oas/v3.0.0) specifications for your REST APIs. This provides interactive documentation, client generation, and API testing tools.

### OpenAPI Builder API

The API uses a fluent builder pattern for constructing endpoints and responses. While experimental and subject to change, it's designed to be used by web framework developers.

#### Building Responses

Responses are constructed using a builder pattern:

```elixir
Code.ensure_loaded!(Person)

# Simple response
user_not_found_response =
  Spectral.OpenAPI.response(404, "User not found")

# Response with body
user_found_response =
  Spectral.OpenAPI.response(200, "User found")
  |> Spectral.OpenAPI.response_with_body(Person, :t)

user_created_response =
  Spectral.OpenAPI.response(201, "User created")
  |> Spectral.OpenAPI.response_with_body(
    Person,
    {:type, :t, 0}
  )

users_found_response =
  Spectral.OpenAPI.response(200, "Users found")
  |> Spectral.OpenAPI.response_with_body(
    Person,
    {:type, :persons, 0}
  )

# Response with response header
response_with_headers =
  Spectral.OpenAPI.response(200, "Success")
  |> Spectral.OpenAPI.response_with_body(Person, :t)
  |> Spectral.OpenAPI.response_with_header(
    "X-Rate-Limit",
    :t,
    %{
      description: "Requests remaining",
      required: false,
      schema: :integer
    }
  )
```

#### Building Endpoints

Endpoints are built by combining the endpoint definition with responses, request bodies, and parameters:
Responses are taken from the previous section.

```elixir
user_get_endpoint =
  Spectral.OpenAPI.endpoint(:get, "/users/{id}")
  |> Spectral.OpenAPI.with_parameter(Person, %{
    name: "id",
    in: :path,
    required: true,
    schema: :string
  })
  |> Spectral.OpenAPI.add_response(user_found_response)
  |> Spectral.OpenAPI.add_response(user_not_found_response)


# Add request body (for POST, PUT, PATCH)
user_create_endpoint =
  Spectral.OpenAPI.endpoint(:post, "/users")
  |> Spectral.OpenAPI.with_request_body(
    Person,
    {:type, :t, 0}
  )
  |> Spectral.OpenAPI.add_response(user_created_response)

# Add parameters
user_search_endpoint =
  Spectral.OpenAPI.endpoint(:get, "/users")
  |> Spectral.OpenAPI.with_parameter(Person, %{
    name: "search",
    in: :query,
    required: false,
    schema: :search
  })
  |> Spectral.OpenAPI.add_response(users_found_response)
```

#### Generating the OpenAPI Specification

Combine all endpoints into a complete OpenAPI spec:

```elixir
metadata = %{
  title: "My API",
  version: "1.0.0"
}


endpoints = [
  #user_get_endpoint,
  user_create_endpoint,
  #user_search_endpoint
]

{:ok, openapi_spec} =
  Spectral.OpenAPI.endpoints_to_openapi(metadata, endpoints)

IO.inspect(openapi_spec, pretty: true)
```

## Requirements

- **Compilation**: Modules must be compiled with `debug_info` for Spectral to extract type information. This is enabled by default in Mix projects.

## Error Handling

Spectral provides two types of functions with different error handling strategies:

### Normal Functions

The standard functions (`encode/3-4`, `decode/3-4`, `schema/2-3`) use a dual error handling approach:

**Data validation errors** return `{:error, [%Spectral.Error{}]}` tuples:
- Type mismatches (e.g., string when integer expected)
- Missing required fields
- Invalid data structure
- Decoding failures

Use `with` for clean error handling:

```elixir
bad_json = ~s({"name":"Alice","age":"not a number"})

with {:ok, person} <- Spectral.decode(bad_json, Person, :t) do
  process_person(person)
end
```

**Type and configuration errors** raise exceptions:
- Module not found, unloaded, or compiled without `debug_info`
- Type not found in the specified module
- Unsupported types used (e.g., `pid()`, `port()`, `tuple()`)

These exceptions indicate problems with your application's configuration or type definitions, not with the data being processed.

### Bang Functions

The bang versions (`encode!/3-4`, `decode!/3-4`, `schema!/2-3`) always raise exceptions for any error:

```elixir
person =
  bad_json
  |> Spectral.decode!(Person, :t)
  |> process_person()
```

Use bang functions when you want to propagate all errors as exceptions, simplifying pipelines but requiring try/rescue for error handling.

### Error Structure

Each `Spectral.Error` struct represents a single error with the following fields:
- `location` - Path showing where the error occurred (e.g., `["user", "age"]`)
- `type` - Error type: `:decode_error`, `:type_mismatch`, `:no_match`, `:missing_data`, `:not_matched_fields`
- `context` - Additional context information about the error
- `message` - Human-readable error message (auto-generated)

Functions return `{:error, [%Spectral.Error{}]}` - a list of error structs:

```elixir
{:error, [
  %Spectral.Error{
    location: ["user", "age"],
    type: :type_mismatch,
    context: %{expected: :integer, got: "not a number"},
    message: "type_mismatch at user.age"
  }
]}
```

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
