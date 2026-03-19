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
        def encode(_format, MyGeoModule, {:type, :point, 0}, {x, y}, _params)
            when is_number(x) and is_number(y) do
          {:ok, [x, y]}
        end

        def encode(_format, MyGeoModule, {:type, :point, 0}, data, _params) do
          {:error, [type_mismatch({:type, :point, 0}, data)]}
        end

        # Types not handled by this codec → continue to default
        def encode(_format, _module, _type_ref, _data, _params), do: :continue

        @impl Spectral.Codec
        def decode(_format, MyGeoModule, {:type, :point, 0}, [x, y], _params)
            when is_number(x) and is_number(y) do
          {:ok, {x, y}}
        end

        def decode(_format, MyGeoModule, {:type, :point, 0}, data, _params) do
          {:error, [type_mismatch({:type, :point, 0}, data)]}
        end

        def decode(_format, _module, _type_ref, _input, _params), do: :continue

        @impl Spectral.Codec
        def schema(:json_schema, MyGeoModule, {:type, :point, 0}, _params) do
          %{type: "array", items: %{type: "number"}, minItems: 2, maxItems: 2}
        end
      end

  ## The `params` argument

  The fifth argument to each callback is the value of the `type_parameters` key
  in the `spectral` attribute placed before the type definition, or `:undefined`
  if no such attribute is present. It is a static, per-type configuration value —
  it is **not** related to Erlang type variables.

  ## Return Values

  - `{:ok, result}` — Use this result instead of the default
  - `{:error, errors}` — The data is invalid for a type this codec handles; `errors`
    is a list of `%Spectral.Error{}` structs (use `type_mismatch/2,3` and similar
    helpers imported by `use Spectral.Codec`)
  - `:continue` — This codec does not handle this type; fall through to spectra's
    built-in structural codec

  The distinction between `{:error, ...}` and `:continue` matters: return `{:error, ...}`
  when the data has the wrong shape for a type your codec *owns*, and `:continue` for
  type references your codec does not recognise at all.

  ## Global Codec Registry

  To use a codec for types defined in a *different* module (e.g., a stdlib or
  third-party type you cannot annotate), register it via the application environment:

      Application.put_env(:spectra, :codecs, %{
        {DateTime, {:type, :t, 0}} => Spectral.Codec.DateTime
      })
  """

  @typedoc "Return value for `encode/5` callback."
  @type encode_result :: {:ok, term()} | {:error, [Spectral.Error.t()]} | :continue

  @typedoc "Return value for `decode/5` callback."
  @type decode_result :: {:ok, term()} | {:error, [Spectral.Error.t()]} | :continue

  @doc """
  Encodes `data` of the given `type_ref` (defined in `module`) to `format`.

  Called by spectra when encoding a value whose type is defined in a codec module.
  Return `{:error, errors}` when the data is invalid for a type your codec handles,
  or `:continue` for types this codec does not recognise.

  `params` is the value of `type_parameters` from the `spectral` attribute on the
  type definition, or `:undefined` if absent.
  """
  @callback encode(
              format :: atom(),
              module :: module(),
              type_ref :: Spectral.sp_type_reference(),
              data :: term(),
              params :: term()
            ) :: encode_result()

  @doc """
  Decodes `input` from `format` into the Elixir value described by `type_ref` (defined in `module`).

  Called by spectra when decoding a value whose type is defined in a codec module.
  Return `{:error, errors}` when the input is invalid for a type your codec handles,
  or `:continue` for types this codec does not recognise.

  `params` is the value of `type_parameters` from the `spectral` attribute on the
  type definition, or `:undefined` if absent.
  """
  @callback decode(
              format :: atom(),
              module :: module(),
              type_ref :: Spectral.sp_type_reference(),
              input :: term(),
              params :: term()
            ) :: decode_result()

  @doc """
  Returns a schema map for `type_ref` (defined in `module`) in `format`.

  This callback is optional. If not implemented, spectra will raise
  `{:schema_not_implemented, module, type_ref}` when schema generation is requested
  for a type owned by this codec.

  `params` is the value of `type_parameters` from the `spectral` attribute on the
  type definition, or `:undefined` if absent.
  """
  @callback schema(
              format :: atom(),
              module :: module(),
              type_ref :: Spectral.sp_type_reference(),
              params :: term()
            ) :: map()

  @optional_callbacks schema: 4

  @doc """
  Creates a `type_mismatch` error for `value` not matching `type_ref`.

  Imported automatically by `use Spectral.Codec`.
  """
  def type_mismatch(type_ref, value) do
    %Spectral.Error{type: :type_mismatch, location: [], context: %{type: type_ref, value: value}}
  end

  @doc """
  Creates a `type_mismatch` error with additional context.

  Use `ctx` to pass extra information — for example `%{reason: :invalid_format}`
  when the value has the right type but the wrong shape.

  Imported automatically by `use Spectral.Codec`.
  """
  def type_mismatch(type_ref, value, ctx) when is_map(ctx) do
    %Spectral.Error{
      type: :type_mismatch,
      location: [],
      context: Map.merge(%{type: type_ref, value: value}, ctx)
    }
  end

  @doc false
  def __convert_result__({:error, errors}) when is_list(errors) do
    {:error, Enum.map(errors, &to_sp_error/1)}
  end

  def __convert_result__(other), do: other

  defp to_sp_error(%Spectral.Error{} = error), do: Spectral.Error.to_erlang(error)
  defp to_sp_error(other), do: other

  @doc false
  defmacro __before_compile__(_env) do
    quote do
      defoverridable encode: 5, decode: 5

      @impl Spectral.Codec
      def encode(format, module, type_ref, data, params) do
        super(format, module, type_ref, data, params)
        |> Spectral.Codec.__convert_result__()
      end

      @impl Spectral.Codec
      def decode(format, module, type_ref, input, params) do
        super(format, module, type_ref, input, params)
        |> Spectral.Codec.__convert_result__()
      end
    end
  end

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour Spectral.Codec
      @before_compile Spectral.Codec
      import Spectral.Codec, only: [type_mismatch: 2, type_mismatch: 3]
    end
  end
end
