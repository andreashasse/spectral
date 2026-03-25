# Spectral

Spectral provides type-safe data serialization and deserialization for Elixir types. Currently the focus is on JSON.

- **Type-safe conversion**: Convert typed Elixir values to/from external formats such as JSON, ensuring data conforms to the type specification
- **Detailed errors**: Get error messages with location information when validation fails
- **Support for complex scenarios**: Handles unions, structs, atoms, nested structures, and more

## Requirements and Installation

**Requires Erlang/OTP 27+** — Spectral uses the native `json` module introduced in OTP 27.

Add `spectral` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:spectral, "~> 0.9.0"}
  ]
end
```

Your modules must be compiled with `debug_info` for Spectral to extract type information. This is enabled by default in Mix projects.

**Note:** Spectral reads type information from compiled BEAM files, so modules must be defined in files (not in IEx).

## Usage

Here's how to use Spectral for JSON serialization and deserialization:

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
  address: %Person.Address{street: "Ystader Straße", city: "Berlin"}
}

with {:ok, json_iodata} <- Spectral.encode(person, Person, :t, :json) do
  IO.iodata_to_binary(json_iodata)
  # Returns: "{\"address\":{\"city\":\"Berlin\",\"street\":\"Ystader Straße\"},\"age\":30,\"name\":\"Alice\"}"
end

# Decode JSON to a struct
json_string = ~s({"name":"Alice","age":30,"address":{"street":"Ystader Straße","city":"Berlin"}})
{:ok, person} = Spectral.decode(json_string, Person, :t, :json)

# Generate a JSON schema
schema_iodata = Spectral.schema(Person, :t)
IO.iodata_to_binary(schema_iodata)
```

Bang variants raise instead of returning error tuples:

```elixir
json =
  person
  |> Spectral.encode!(Person, :t, :json)
  |> IO.iodata_to_binary()

person = Spectral.decode!(json_string, Person, :t, :json)

schema =
  Person
  |> Spectral.schema(:t)
  |> IO.iodata_to_binary()
```

## Data Serialization API

**Parameters** for `encode/3-5`, `decode/3-5`, and `schema/2-3`:

- `data` — The data to encode/decode (Elixir value for encode, binary/iodata for decode)
- `module` — The module where the type is defined (e.g., `Person`)
- `type_ref` — The type reference, typically an atom like `:t` for `@type t`
- `format` — (optional) The data format: `:json` (default), `:binary_string`, or `:string`

The `binary_string` and `string` formats decode a single value from a binary or string — useful for path variables and query parameters:

```elixir
defmodule MyTypes do
  use Spectral

  @type role :: :admin | :user
end

# Decode a role from a query parameter like "?role=admin"
{:ok, :admin} = Spectral.decode("admin", MyTypes, :role, :binary_string)
{:error, _} = Spectral.decode("superuser", MyTypes, :role, :binary_string)

# Encode a role back to a plain string
{:ok, "admin"} = Spectral.encode(:admin, MyTypes, :role, :binary_string)
```

### Options

`encode/5` and `decode/5` accept an options list as the last argument:

| Option | Function | Effect |
|--------|----------|--------|
| `pre_decoded` | `decode` | Input is already a parsed term — skips JSON decoding |
| `pre_encoded` | `encode`, `schema` | Returns a map/list instead of `iodata()` — skips JSON encoding |

```elixir
# Input already decoded by a web framework (e.g. Plug already ran Jason.decode!)
{:ok, person} = Spectral.decode(decoded_map, Person, :t, :json, [:pre_decoded])

# Get a map instead of iodata (e.g. to pass to a framework that does its own encoding)
{:ok, map} = Spectral.encode(person, Person, :t, :json, [:pre_encoded])

# Get the schema as a map instead of iodata
schema_map = Spectral.schema(Person, :t, :json_schema, [:pre_encoded])
```

## Error Handling

`encode/3-5` and `decode/3-5` use a dual error handling strategy:

**Data validation errors** return `{:error, [%Spectral.Error{}]}`:
- Type mismatches (e.g., string when integer expected)
- Missing required fields
- Invalid data structure

**Configuration errors** raise exceptions:
- Module not found, unloaded, or compiled without `debug_info`
- Type not found in the specified module
- Unsupported types (e.g., `pid()`, `port()`, `tuple()`)

Use `with` for clean error handling:

```elixir
bad_json = ~s({"name":"Alice","age":"not a number"})

with {:ok, person} <- Spectral.decode(bad_json, Person, :t, :json) do
  process_person(person)
end
```

Bang functions (`encode!/3-5`, `decode!/3-5`) raise for any error, including data validation errors. Use them when you want to propagate all errors as exceptions.

`schema/2-3` returns `iodata()` directly (no result tuple) but may still raise for configuration errors.

### Error Structure

Each `%Spectral.Error{}` has:
- `location` — path to the failing value, e.g. `["user", "age"]`
- `type` — `:type_mismatch`, `:missing_data`, `:no_match`, or `:not_matched_fields`
- `context` — additional context, e.g. `%{expected: :integer, got: "not a number"}`
- `message` — human-readable error message

## Nil Values, Extra Fields, and Special Types

### Nil values

Struct fields with `nil` values are omitted when encoding if the type allows `nil`. When decoding, missing fields and explicit JSON `null` both become `nil` if the type allows it:

```elixir
person = %Person{name: "Alice"}  # age and address are nil

with {:ok, json_iodata} <- Spectral.encode(person, Person, :t, :json) do
  IO.iodata_to_binary(json_iodata)
  # Returns: "{\"name\":\"Alice\"}"  (age and address omitted)
end

Spectral.decode(~s({"name":"Alice"}), Person, :t, :json)
# Returns: {:ok, %Person{name: "Alice", age: nil, address: nil}}

Spectral.decode(~s({"name":"Alice","age":null}), Person, :t, :json)
# Returns: {:ok, %Person{name: "Alice", age: nil, address: nil}}
```

### Extra fields

Extra JSON fields not present in the type specification are silently ignored, enabling forward compatibility:

```elixir
json = ~s({"name":"Alice","age":30,"unknown_field":"ignored"})
Spectral.decode(json, Person, :t, :json)
# Returns: {:ok, %Person{name: "Alice", age: 30, address: nil}}
```

### `dynamic()`, `term()`, and `any()`

Spectral does not validate or reject data of these types. The result may not be valid JSON if encoding such data.

### Unsupported types

The following types cannot be serialized to JSON:
- `pid()`, `port()`, `reference()`
- `tuple()` (generic unstructured tuples)
- Function types

## Custom Codecs

You can write a codec for any type by implementing the `Spectral.Codec` behaviour. Add `use Spectral.Codec` to your module — spectra auto-detects it via the `@behaviour` attribute in the compiled BEAM, so no registration is needed for types defined in your own module.

Here is a codec that serializes a `point` tuple as a two-element JSON array:

```elixir
defmodule MyGeoModule do
  use Spectral.Codec

  @opaque point :: {float(), float()}

  @impl Spectral.Codec
  def encode(_format, MyGeoModule, {:type, :point, 0}, {x, y}, _sp_type, _params)
      when is_number(x) and is_number(y) do
    {:ok, [x, y]}
  end

  def encode(_format, MyGeoModule, {:type, :point, 0}, data, _sp_type, _params) do
    {:error, [%Spectral.Error{type: :type_mismatch, location: [], context: %{type: {:type, :point, 0}, value: data}}]}
  end

  def encode(_format, _module, _type_ref, _data, _sp_type, _params), do: :continue

  @impl Spectral.Codec
  def decode(_format, MyGeoModule, {:type, :point, 0}, [x, y], _sp_type, _params)
      when is_number(x) and is_number(y) do
    {:ok, {x, y}}
  end

  def decode(_format, MyGeoModule, {:type, :point, 0}, data, _sp_type, _params) do
    {:error, [%Spectral.Error{type: :type_mismatch, location: [], context: %{type: {:type, :point, 0}, value: data}}]}
  end

  def decode(_format, _module, _type_ref, _input, _sp_type, _params), do: :continue

  @impl Spectral.Codec
  def schema(:json_schema, MyGeoModule, {:type, :point, 0}, _sp_type, _params) do
    %{type: "array", items: %{type: "number"}, minItems: 2, maxItems: 2}
  end
end
```

Each callback must return `{:ok, result}`, `{:error, errors}`, or `:continue`. Return `{:error, ...}` when the data is invalid for a type your codec *owns*, and `:continue` for types your codec does not handle.

### Codec errors

Do not raise exceptions or return plain maps from codec callbacks. Construct `%Spectral.Error{}` structs with `type: :type_mismatch` for errors (as shown above). Spectral's behaviour converts these structs to the Erlang record format spectra expects, collecting errors from multiple locations and attaching path information as it traverses nested structures.

### Optional `schema/5` callback

The `schema/5` callback is optional. If a codec module does not export it, calling `Spectral.schema/3` for a type owned by that codec raises `{:schema_not_implemented, Module, TypeRef}`. Return `:continue` for types the codec does not handle.

### Codecs for third-party types

To handle types from modules you cannot annotate (stdlib, third-party libraries), register a codec globally:

```elixir
Application.put_env(:spectra, :codecs, %{
  {SomeLibrary, {:type, :some_type, 0}} => MyCodec
})
```

The module is passed as the second argument to all callbacks, so each clause is unambiguous regardless of how the codec was registered.

## Built-in Codecs

Spectral ships with codecs for Elixir's standard date/time types. They are not active by default — register them in `config/config.exs`:

```elixir
import Config

config :spectra, :codecs, %{
  {DateTime, {:type, :t, 0}} => Spectral.Codec.DateTime,
  {Date, {:type, :t, 0}} => Spectral.Codec.Date,
  {MapSet, {:type, :t, 0}} => Spectral.Codec.MapSet,
  {MapSet, {:type, :t, 1}} => Spectral.Codec.MapSet
}
```

| Codec | Elixir type | JSON representation |
|---|---|---|
| `Spectral.Codec.DateTime` | `DateTime.t()` | ISO 8601 / RFC 3339 string, e.g. `"2012-04-23T18:25:43.511Z"` |
| `Spectral.Codec.Date` | `Date.t()` | ISO 8601 date string, e.g. `"2023-04-01"` |
| `Spectral.Codec.MapSet` | `MapSet.t()` / `MapSet.t(elem)` | JSON array with `uniqueItems: true` in its schema |

The date/time codecs handle `:json` and `:binary_string` formats. A string that fails to parse returns a `type_mismatch` error with `%{reason: :invalid_format}` in the error context.

If you use any of these types without registering the codec, encoding and decoding fall through to spectra's structural codec, which cannot handle these opaque structs. Schema generation raises `{:schema_not_implemented, Module, type_ref}`. Register the codecs before your application starts processing these types.

`Range` and `Stream` do not have built-in codecs. Implement a custom `Spectral.Codec` if needed — PRs welcome.

## Type Parameters

The `type_parameters` key in a `spectral` attribute attaches a static value to a type. This value is available to codecs as the `params` argument (6th argument to `encode/6` and `decode/6`, 5th to `schema/5`). When `type_parameters` is absent, `params` is `:undefined`.

### String and binary constraints

For `String.t()`, `binary()`, `nonempty_binary()`, and `nonempty_string()`, `type_parameters` can enforce structural constraints — **no custom codec required**:

| Key | JSON Schema keyword | Validated at encode/decode? | Notes |
|---|---|---|---|
| `min_length` | `minLength` | yes | Unicode codepoint count, not byte count |
| `max_length` | `maxLength` | yes | Unicode codepoint count, not byte count |
| `pattern` | `pattern` | yes | PCRE regular expression |
| `format` | `format` | no | Schema annotation only |

```elixir
defmodule MyTypes do
  use Spectral

  spectral type_parameters: %{min_length: 2, max_length: 64}
  @type username :: String.t()

  spectral type_parameters: %{pattern: "^[a-z0-9_]+$", format: "hostname"}
  @type slug :: String.t()
end
```

Encoding and decoding both enforce the constraints and return an error on failure. `nonempty_binary()` and `nonempty_string()` already imply `minLength: 1`; a `min_length` parameter overrides this.

### Codec-specific configuration

`type_parameters` also lets you reuse one codec across multiple types with different configuration:

```elixir
defmodule MyIds do
  use Spectral.Codec
  use Spectral

  spectral(type_parameters: "user_")
  @type user_id :: String.t()

  spectral(type_parameters: "org_")
  @type org_id :: String.t()

  @impl Spectral.Codec
  def encode(_format, MyIds, {:type, type, 0}, id, _sp_type, prefix)
      when type in [:user_id, :org_id] and is_binary(id) do
    {:ok, prefix <> id}
  end

  def encode(_format, MyIds, {:type, type, 0}, data, _sp_type, _prefix)
      when type in [:user_id, :org_id] do
    {:error, [%Spectral.Error{type: :type_mismatch, location: [], context: %{type: {:type, type, 0}, value: data}}]}
  end

  def encode(_format, _module, _type_ref, _data, _sp_type, _params), do: :continue

  @impl Spectral.Codec
  def decode(_format, MyIds, {:type, type, 0}, encoded, _sp_type, prefix)
      when type in [:user_id, :org_id] and is_binary(encoded) do
    prefix_len = byte_size(prefix)

    case encoded do
      <<^prefix::binary-size(prefix_len), id::binary>> -> {:ok, id}
      _ -> {:error, [%Spectral.Error{type: :type_mismatch, location: [], context: %{type: {:type, type, 0}, value: encoded}}]}
    end
  end

  def decode(_format, _module, _type_ref, _input, _sp_type, _params), do: :continue

  @impl Spectral.Codec
  def schema(_format, MyIds, {:type, type, 0}, _sp_type, prefix) when type in [:user_id, :org_id] do
    %{type: "string", pattern: "^" <> prefix}
  end
end
```

## Documenting Types with `spectral`

You can add JSON Schema documentation to your types using the `spectral` macro. Place the `spectral` call immediately before the `@type` definition it documents:

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

**Supported fields for types:**
- `title` — short title for the type
- `description` — longer description
- `deprecated` — marks the type as deprecated (boolean); emitted as `"deprecated": true` in the JSON Schema
- `examples` — list of example values
- `examples_function` — `{module, function_name, args}` tuple; the function is called at schema generation time to produce examples. Use this instead of `examples` when constructing values inline is awkward. The function must be exported.
- `type_parameters` — passed as `params` to codec callbacks (see [Custom Codecs](#custom-codecs))

```elixir
defmodule Person do
  use Spectral

  defstruct [:name, :age]

  spectral title: "Person",
           description: "A person with name and age",
           examples_function: {__MODULE__, :examples, []}
  @type t :: %Person{name: String.t(), age: non_neg_integer()}

  def examples do
    [%Person{name: "Alice", age: 30}, %Person{name: "Bob", age: 25}]
  end
end
```

The generated schema will include the title and description:

```elixir
schema = Spectral.schema(Person, :t) |> IO.iodata_to_binary() |> Jason.decode!()
# %{"title" => "Person", "description" => "A person with name and age", "type" => "object", ...}
```

**Multiple types in one module** — only types with a `spectral` call will have title/description in their schemas:

```elixir
defmodule MyModule do
  use Spectral

  spectral title: "Public API", description: "The public interface"
  @type public_api :: map()

  # No spectral call — no title/description in schema
  @type internal_type :: atom()
end
```

### Documenting Functions (Endpoint Metadata)

The `spectral` macro also works before `@spec` definitions to attach OpenAPI endpoint documentation:

```elixir
defmodule MyController do
  use Spectral

  spectral summary: "Get user", description: "Returns a user by ID"
  @spec show(map(), map()) :: map()
  def show(_conn, _params), do: %{}
end
```

**Supported fields for function specs:**
- `summary` — short summary of the endpoint operation
- `description` — longer description
- `deprecated` — boolean

This metadata is used by `Spectral.OpenAPI.endpoint/5` to automatically populate OpenAPI operation fields — see the OpenAPI section below.

## OpenAPI Specification

> **Note:** Most users will not need to use `Spectral.OpenAPI` directly. Web framework integrations such as [phoenix_spec](https://github.com/andreashasse/phoenix_spec) build on top of it and provide a higher-level API. Use `Spectral.OpenAPI` only if you are building such an integration or need direct control over spec generation.

Spectral can generate complete [OpenAPI 3.1](https://spec.openapis.org/oas/v3.1.0) specifications for your REST APIs. This provides interactive documentation, client generation, and API testing tools.

### OpenAPI Builder API

The API uses a fluent builder pattern for constructing endpoints and responses.

#### Building Responses

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
  |> Spectral.OpenAPI.response_with_body(Person, {:type, :t, 0})

users_found_response =
  Spectral.OpenAPI.response(200, "Users found")
  |> Spectral.OpenAPI.response_with_body(Person, {:type, :persons, 0})

# Response with response header
response_with_headers =
  Spectral.OpenAPI.response(200, "Success")
  |> Spectral.OpenAPI.response_with_body(Person, :t)
  |> Spectral.OpenAPI.response_with_header(
    "X-Rate-Limit",
    :t,
    %{description: "Requests remaining", required: false, schema: :integer}
  )
```

#### Building Endpoints

Use `endpoint/5` to automatically pull documentation from a function's `spectral` annotation:

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

# Add query parameters
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

`endpoints_to_openapi/3` accepts the same `pre_encoded` option as `encode/5`:

| Options | Return on success |
|---------|------------------|
| (default) | `{:ok, iodata()}` — encoded JSON |
| `[:pre_encoded]` | `{:ok, map()}` — decoded map for further processing |

```elixir
{:ok, spec_map} = Spectral.OpenAPI.endpoints_to_openapi(metadata, endpoints, [:pre_encoded])
```

## Related Projects

- **[spectra](https://github.com/andreashasse/spectra)** - The underlying Erlang library that powers Spectral

## Development Status

This library is under active development. APIs may change in future versions.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

See LICENSE.md for details.
