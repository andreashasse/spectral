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
    {:spectral, "~> 0.7.0"}
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
schema_iodata = Spectral.schema(Person, :t)
IO.iodata_to_binary(schema_iodata)
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
  |> Spectral.schema(:t)
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

# When decoding, both missing fields and explicit null values become nil in structs
Spectral.decode(~s({"name":"Alice"}), Person, :t)
# Returns: {:ok, %Person{name: "Alice", age: nil, address: nil}}

Spectral.decode(~s({"name":"Alice","age":null,"address":null}), Person, :t)
# Returns: {:ok, %Person{name: "Alice", age: nil, address: nil}}
```

### Extra Fields Handling

When decoding JSON into Elixir structs, extra fields that are not defined in the type specification are **silently ignored**. This enables forward compatibility and flexible API evolution:

```elixir
# JSON with extra fields not in the Person type
json = ~s({"name":"Alice","age":30,"unknown_field":"ignored"})

Spectral.decode(json, Person, :t)
# Returns: {:ok, %Person{name: "Alice", age: 30, address: nil}}
# Extra fields are discarded without errors
```

This permissive behavior allows your application to accept JSON from newer API versions without breaking, as long as all required fields are present.

### Data Serialization API

The main functions for JSON serialization and deserialization (pipe-friendly):

```elixir
# Regular versions (return tuples)
Spectral.encode(data, module, type_ref, format \\ :json) ::
    {:ok, iodata()} | {:error, [%Spectral.Error{}]}

Spectral.encode!(data, module, type_ref, format \\ :json) :: iodata()

Spectral.decode(data, module, type_ref, format \\ :json) ::
    {:ok, dynamic()} | {:error, [%Spectral.Error{}]}

Spectral.decode!(data, module, type_ref, format \\ :json) :: dynamic()
```

**Parameters:**
- `data` - The data to encode/decode (Elixir value for encode, binary/string for decode)
- `module` - The module where the type is defined (e.g., `Person`)
- `type_ref` - The type reference, typically an atom like `:t` for the `@type t` definition
- `format` - (optional) The data format: `:json` (default), `:binary_string`, or `:string`

### Schema API

Generate schemas from your type definitions:

```elixir
Spectral.schema(module, type_ref, format \\ :json_schema) :: iodata()
```

**Parameters:**
- `module` - The module where the type is defined
- `type_ref` - The type reference
- `format` - (optional) Schema format, currently supports `:json_schema` (default)

### Built-in Codecs

Spectral ships with codecs for Elixir's standard date/time types. They are not active by default — register them in your application's `config/config.exs` or in your `Application.start/2` callback:

```elixir
# config/config.exs (or config/runtime.exs)
import Config

config :spectra, :codecs, %{
  {DateTime, {:type, :t, 0}} => Spectral.Codec.DateTime,
  {Date, {:type, :t, 0}} => Spectral.Codec.Date
}
```

| Codec | Elixir type | Format | Example |
|---|---|---|---|
| `Spectral.Codec.DateTime` | `DateTime.t()` | ISO 8601 / RFC 3339 | `"2012-04-23T18:25:43.511Z"` |
| `Spectral.Codec.Date` | `Date.t()` | ISO 8601 | `"2023-04-01"` |

Both codecs handle `:json` and `:binary` formats (binary string) and `:string` format (charlist). A string that fails to parse returns a `type_mismatch` error with `%{reason: :invalid_format}` in the error context, distinguishing a wrong type from a badly formatted string.

If you use `DateTime.t()` or `Date.t()` without registering the codec, encoding and decoding fall through to spectra's structural codec, which cannot handle these opaque structs. Schema generation raises `{:schema_not_implemented, DateTime, {:type, :t, 0}}`. Register the codecs before your application starts processing these types.

### Custom Codecs

You can write a codec for any type by implementing the `Spectral.Codec` behaviour. Add `use Spectral.Codec` to your module — spectra auto-detects it via the `@behaviour` attribute in the compiled BEAM, so no registration is needed for types defined in your own module.

#### Static per-type configuration with `type_parameters`

The `type_parameters` key in a `spectral` attribute passes a static value to your codec as the `params` argument. This is useful for reusing one codec across multiple types with different configuration:

```elixir
defmodule MyIds do
  use Spectral.Codec
  use Spectral

  spectral(type_parameters: "user_")
  @type user_id :: String.t()

  spectral(type_parameters: "org_")
  @type org_id :: String.t()

  @impl Spectral.Codec
  def encode(_format, MyIds, {:type, type, 0}, id, prefix)
      when type in [:user_id, :org_id] and is_binary(id) do
    {:ok, prefix <> id}
  end

  def encode(_format, MyIds, {:type, type, 0}, data, _prefix)
      when type in [:user_id, :org_id] do
    {:error, [:sp_error.type_mismatch({:type, type, 0}, data)]}
  end

  def encode(_format, _module, _type_ref, _data, _params), do: :continue

  @impl Spectral.Codec
  def decode(_format, MyIds, {:type, type, 0}, encoded, prefix)
      when type in [:user_id, :org_id] and is_binary(encoded) do
    prefix_len = byte_size(prefix)

    case encoded do
      <<^prefix::binary-size(prefix_len), id::binary>> -> {:ok, id}
      _ -> {:error, [:sp_error.type_mismatch({:type, type, 0}, encoded)]}
    end
  end

  def decode(_format, _module, _type_ref, _input, _params), do: :continue

  @impl Spectral.Codec
  def schema(_format, MyIds, {:type, type, 0}, prefix) when type in [:user_id, :org_id] do
    %{type: "string", pattern: "^" <> prefix}
  end
end
```

When no `type_parameters` attribute is present, `params` is `:undefined`.

#### Codecs for third-party types

To handle types from modules you cannot annotate (stdlib, third-party libraries), register a codec globally:

```elixir
Application.put_env(:spectra, :codecs, %{
  {SomeLibrary, {:type, :some_type, 0}} => MyCodec
})
```

The module is passed as the second argument to all callbacks, so each clause is unambiguous regardless of how the codec was registered.

### Documenting Types with `spectral`

You can add JSON Schema documentation (title, description, examples) to your types using the `spectral` macro:

```elixir
defmodule Person do
  use Spectral

  defstruct [:name, :age]

  spectral title: "Person", description: "A person with name and age"
  @type t :: %Person{
    name: String.t(),
    age: non_neg_integer() | nil
  }
end
```

Place the `spectral` call before the `@type` definition it documents. When you generate a JSON schema, it will include the title and description:

```elixir
schema = Spectral.schema(Person, :t) |> IO.iodata_to_binary() |> Jason.decode!()
# %{
#   "title" => "Person",
#   "description" => "A person with name and age",
#   "type" => "object",
#   ...
# }
```

**Supported fields:**
- `title` - A short title for the type
- `description` - A longer description of what the type represents
- `examples` - A list of example values (not yet fully supported)

**Multiple types in one module:**

If you have multiple types in a module, you only need to document the types you want. Types without `spectral` calls won't have title/description in their schemas:

```elixir
defmodule MyModule do
  use Spectral

  # Documented type
  spectral title: "Public API", description: "The public interface"
  @type public_api :: map()

  # Undocumented type - no spectral call needed
  @type internal_type :: atom()
end
```

### Documenting Functions (Endpoint Metadata)

The `spectral` macro also works before `@spec` definitions to attach OpenAPI endpoint documentation to functions:

```elixir
defmodule MyController do
  use Spectral

  spectral summary: "Get user", description: "Returns a user by ID"
  @spec show(map(), map()) :: map()
  def show(_conn, _params), do: %{}
end
```

**Supported fields:**
- `summary` - Short summary of the endpoint operation
- `description` - Longer description of the operation
- `deprecated` - Whether the endpoint is deprecated (boolean)

This metadata is used by `Spectral.OpenAPI.endpoint/5` to automatically populate OpenAPI operation fields — see the OpenAPI section below.

## OpenAPI Specification

> **Note:** Most users will not need to use `Spectral.OpenAPI` directly. Web framework integrations such as [phoenix_spec](https://github.com/andreashasse/phoenix_spec) build on top of it and provide a higher-level API. Use `Spectral.OpenAPI` only if you are building such an integration or need direct control over spec generation.

Spectral can generate complete [OpenAPI 3.1](https://spec.openapis.org/oas/v3.1.0) specifications for your REST APIs. This provides interactive documentation, client generation, and API testing tools.

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

Endpoints are built by combining the endpoint definition with responses, request bodies, and parameters.

Use `endpoint/5` to automatically pull the endpoint documentation from a function's `spectral/1` annotation:

```elixir
# Documentation comes from the spectral/1 annotation on MyController.show/2
user_get_endpoint =
  Spectral.OpenAPI.endpoint(:get, "/users/{id}", MyController, :show, 2)
  |> Spectral.OpenAPI.add_response(user_found_response)
```

Or use `endpoint/3` to pass documentation inline:

```elixir
user_get_endpoint =
  Spectral.OpenAPI.endpoint(:get, "/users/{id}", %{summary: "Get user by ID"})
  |> Spectral.OpenAPI.with_parameter(Person, %{
    name: "id",
    in: :path,
    required: true,
    schema: :string,
    description: "The user ID"
  })
  |> Spectral.OpenAPI.add_response(user_found_response)
  |> Spectral.OpenAPI.add_response(user_not_found_response)


# Add request body (for POST, PUT, PATCH)
# Description comes automatically from the spectral attribute on Person.t()
user_create_endpoint =
  Spectral.OpenAPI.endpoint(:post, "/users")
  |> Spectral.OpenAPI.with_request_body(Person, {:type, :t, 0})
  |> Spectral.OpenAPI.add_response(user_created_response)

# Override content type (defaults to "application/json")
user_create_xml_endpoint =
  Spectral.OpenAPI.endpoint(:post, "/users")
  |> Spectral.OpenAPI.with_request_body(Person, {:type, :t, 0}, "application/xml")
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
  version: "1.0.0",
  # Optional fields:
  summary: "Short summary of the API",
  description: "Longer description of the API",
  terms_of_service: "https://example.com/terms",
  contact: %{name: "Support", url: "https://example.com/support", email: "support@example.com"},
  license: %{name: "MIT", url: "https://opensource.org/licenses/MIT"},
  servers: [%{url: "https://api.example.com", description: "Production"}]
}


endpoints = [
  user_get_endpoint,
  user_create_endpoint,
  user_search_endpoint
]

{:ok, json} = Spectral.OpenAPI.endpoints_to_openapi(metadata, endpoints)
```

`endpoints_to_openapi/2` returns `{:ok, iodata}` — the complete OpenAPI 3.1 spec serialised as JSON, ready to write to a file or serve over HTTP.

## Requirements

- **Erlang/OTP 27+**: Spectral requires Erlang/OTP version 27 or later (required by the underlying spectra library)
- **Compilation**: Modules must be compiled with `debug_info` for Spectral to extract type information. This is enabled by default in Mix projects.

## Error Handling

Spectral provides two types of functions with different error handling strategies:

### Normal Functions

The encoding and decoding functions (`encode/3-4`, `decode/3-4`) use a dual error handling approach:

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

The bang versions (`encode!/3-4`, `decode!/3-4`) always raise exceptions for any error:

```elixir
person =
  bad_json
  |> Spectral.decode!(Person, :t)
  |> process_person()
```

Use bang functions when you want to propagate all errors as exceptions, simplifying pipelines but requiring try/rescue for error handling.

### Schema Generation

The `schema/2-3` function returns the schema directly as `iodata()` without wrapping it in a result tuple:

```elixir
schema = Spectral.schema(Person, :t)
IO.iodata_to_binary(schema)
```

Schema generation may still raise exceptions for type and configuration errors (module not found, type not found, etc.).

### sp_error records

`%Spectral.Error{}` structs are the Elixir view of errors, but the underlying spectra library works with `sp_error` Erlang records. You will encounter these when writing a custom codec — the `:sp_error` module (from the `spectra` dependency, available automatically) provides helpers to construct them.

Do not raise an exception or return a plain map from a codec callback. Spectra expects the `sp_error` record format so it can collect errors from multiple locations, attach path information as it traverses nested structures, and convert them to `%Spectral.Error{}` via `Spectral.Error.from_erlang_list/1` before returning to the caller.

The most common helper is `:sp_error.type_mismatch(type_ref, bad_value)`. Pass an optional third argument map to add context — for example `%{reason: :invalid_format}` when the value has the right type but the wrong shape. Other helpers: `:sp_error.missing_data/3`, `:sp_error.no_match/3`. See the `sp_error` module in the spectra source for the full list.

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

### `dynamic()`, `term()` and `any()`

When using types with `dynamic()`, `term()`, or `any()` in your type specifications, Spectral will not reject any data, which means it can return data that may not be valid JSON.

Note: Spectral uses `dynamic()` for runtime-determined types in its own API, following Erlang's gradual typing conventions.

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
