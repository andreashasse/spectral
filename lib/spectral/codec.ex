defmodule Spectral.Codec do
  @moduledoc """
  Behaviour for custom codec modules.

  A custom codec lets you override the default encode/decode/schema logic for specific
  types in your module. When spectra encounters a type defined in a codec module, it
  calls your callbacks first. Return `{:ok, result}` to provide a custom result,
  `{:error, errors}` when the data is invalid for a type your codec owns, or `:continue`
  to fall through to spectra's built-in structural encoding/decoding for types your
  codec does not handle.

  ## Usage

  Add `use Spectral.Codec` to your module and implement the required callbacks.
  Spectra detects codec modules by checking for `@behaviour Spectral.Codec` in
  the compiled BEAM, so no extra registration is needed:

      defmodule MyGeoModule do
        use Spectral.Codec

        @opaque point :: {float(), float()}

        @impl Spectral.Codec
        def encode(_format, {:type, :point, 0}, {x, y}, _params)
            when is_number(x) and is_number(y) do
          {:ok, [x, y]}
        end

        def encode(_format, {:type, :point, 0}, data, _params) do
          # Bad data for a type this codec owns → return an error
          {:error, [:sp_error.type_mismatch({:type, :point, 0}, data)]}
        end

        # Types not handled by this codec → continue to default
        def encode(_format, _type_ref, _data, _params), do: :continue

        @impl Spectral.Codec
        def decode(_format, {:type, :point, 0}, [x, y], _params)
            when is_number(x) and is_number(y) do
          {:ok, {x, y}}
        end

        def decode(_format, {:type, :point, 0}, data, _params) do
          {:error, [:sp_error.type_mismatch({:type, :point, 0}, data)]}
        end

        def decode(_format, _type_ref, _input, _params), do: :continue

        @impl Spectral.Codec
        def schema(:json_schema, {:type, :point, 0}, _params) do
          %{type: "array", items: %{type: "number"}, minItems: 2, maxItems: 2}
        end
      end

  ## The `params` argument

  The fourth argument to each callback is the value of the `type_parameters` key
  in the `spectral` attribute placed before the type definition, or `:undefined`
  if no such attribute is present. It is a static, per-type configuration value —
  it is **not** related to Erlang type variables.

  ## Return Values

  - `{:ok, result}` — Use this result instead of the default
  - `{:error, errors}` — The data is invalid for a type this codec handles; `errors`
    is a list of `sp_error` records (use `:sp_error` helper functions to construct them)
  - `:continue` — This codec does not handle this type; fall through to spectra's
    built-in structural codec

  The distinction between `{:error, ...}` and `:continue` matters: return `{:error, ...}`
  when the data has the wrong shape for a type your codec *owns*, and `:continue` for
  type references your codec does not recognise at all.

  ## Global Codec Registry

  To use a codec for types defined in a *different* module (e.g., a stdlib or
  third-party type you cannot annotate), register it via the application environment:

      Application.put_env(:spectra, :codecs, %{
        {Calendar, {:type, :datetime, 0}} => MyDateTimeCodec
      })
  """

  @typedoc "Return value for `encode/4` callback."
  @type encode_result :: {:ok, term()} | {:error, [term()]} | :continue

  @typedoc "Return value for `decode/4` callback."
  @type decode_result :: {:ok, term()} | {:error, [term()]} | :continue

  @doc """
  Encodes `data` of the given `type_ref` to `format`.

  Called by spectra when encoding a value whose type is defined in this module.
  Return `{:error, errors}` when the data is invalid for a type your codec handles,
  or `:continue` for types this codec does not recognise.

  `params` is the value of `type_parameters` from the `spectral` attribute on the
  type definition, or `:undefined` if absent.
  """
  @callback encode(
              format :: atom(),
              type_ref :: Spectral.sp_type_reference(),
              data :: term(),
              params :: term()
            ) :: encode_result()

  @doc """
  Decodes `input` from `format` into the Elixir value described by `type_ref`.

  Called by spectra when decoding a value whose type is defined in this module.
  Return `{:error, errors}` when the input is invalid for a type your codec handles,
  or `:continue` for types this codec does not recognise.

  `params` is the value of `type_parameters` from the `spectral` attribute on the
  type definition, or `:undefined` if absent.
  """
  @callback decode(
              format :: atom(),
              type_ref :: Spectral.sp_type_reference(),
              input :: term(),
              params :: term()
            ) :: decode_result()

  @doc """
  Returns a schema map for `type_ref` in `format`.

  This callback is optional. If not implemented, spectra will raise
  `{:schema_not_implemented, module, type_ref}` when schema generation is requested
  for a type owned by this codec.

  `params` is the value of `type_parameters` from the `spectral` attribute on the
  type definition, or `:undefined` if absent.
  """
  @callback schema(
              format :: atom(),
              type_ref :: Spectral.sp_type_reference(),
              params :: term()
            ) :: map()

  @optional_callbacks schema: 3

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour Spectral.Codec
    end
  end
end
