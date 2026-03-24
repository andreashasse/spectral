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
        def encode(_format, MyGeoModule, {:type, :point, 0}, {x, y}, _sp_type, _params)
            when is_number(x) and is_number(y) do
          {:ok, [x, y]}
        end

        def encode(_format, MyGeoModule, {:type, :point, 0}, data, _sp_type, _params) do
          {:error, [%Spectral.Error{type: :type_mismatch, location: [], context: %{type: {:type, :point, 0}, value: data}}]}
        end

        # Types not handled by this codec → continue to default
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

  ## The `params` argument

  The sixth argument to `encode/6` and `decode/6`, and the fifth to `schema/5`, is the
  value of the `type_parameters` key in the `spectral` attribute placed before the type
  definition, or `:undefined` if no such attribute is present. It is a static,
  per-type configuration value — it is **not** related to Erlang type variables.

  ## The `sp_type` argument

  The fifth argument to `encode/6` and `decode/6`, and the fourth to `schema/5`, is the
  `sp_type()` instantiation node from the type traversal. For generic types (those with
  type variables, such as `dict:dict(key, value)`) this is the reference node and carries
  the concrete type-variable bindings of the current instantiation. Use
  `:spectra_type.type_args/1` to extract them for recursive encoding/decoding.

  For non-generic types this argument is the resolved type definition and
  `:spectra_type.type_args/1` returns `[]`.

  ## Return Values

  - `{:ok, result}` — Use this result instead of the default
  - `{:error, errors}` — The data is invalid for a type this codec handles; `errors`
    is a list of `%Spectral.Error{}` structs
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

  @typedoc "Return value for `encode/6` callback."
  @type encode_result :: {:ok, term()} | {:error, [Spectral.Error.t()]} | :continue

  @typedoc "Return value for `decode/6` callback."
  @type decode_result :: {:ok, term()} | {:error, [Spectral.Error.t()]} | :continue

  @doc """
  Encodes `data` of the given `type_ref` (defined in `module`) to `format`.

  Called by spectra when encoding a value whose type is defined in a codec module.
  Return `{:error, errors}` when the data is invalid for a type your codec handles,
  or `:continue` for types this codec does not recognise.

  `sp_type` is the instantiation node from the type traversal (see module doc).
  `params` is the value of `type_parameters` from the `spectral` attribute on the
  type definition, or `:undefined` if absent.
  """
  @callback encode(
              format :: atom(),
              module :: module(),
              type_ref :: Spectral.sp_type_reference(),
              data :: term(),
              sp_type :: term(),
              params :: term()
            ) :: encode_result()

  @doc """
  Decodes `input` from `format` into the Elixir value described by `type_ref` (defined in `module`).

  Called by spectra when decoding a value whose type is defined in a codec module.
  Return `{:error, errors}` when the input is invalid for a type your codec handles,
  or `:continue` for types this codec does not recognise.

  `sp_type` is the instantiation node from the type traversal (see module doc).
  `params` is the value of `type_parameters` from the `spectral` attribute on the
  type definition, or `:undefined` if absent.
  """
  @callback decode(
              format :: atom(),
              module :: module(),
              type_ref :: Spectral.sp_type_reference(),
              input :: term(),
              sp_type :: term(),
              params :: term()
            ) :: decode_result()

  @doc """
  Returns a schema map for `type_ref` (defined in `module`) in `format`.

  This callback is optional. If not implemented, spectra will raise
  `{:schema_not_implemented, module, type_ref}` when schema generation is requested
  for a type owned by this codec.

  `sp_type` is the instantiation node from the type traversal (see module doc).
  `params` is the value of `type_parameters` from the `spectral` attribute on the
  type definition, or `:undefined` if absent.
  """
  @callback schema(
              format :: atom(),
              module :: module(),
              type_ref :: Spectral.sp_type_reference(),
              sp_type :: term(),
              params :: term()
            ) :: map()

  @optional_callbacks schema: 5

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
      defoverridable encode: 6, decode: 6

      @impl Spectral.Codec
      def encode(format, module, type_ref, data, sp_type, params) do
        super(format, module, type_ref, data, sp_type, params)
        |> Spectral.Codec.__convert_result__()
      end

      @impl Spectral.Codec
      def decode(format, module, type_ref, input, sp_type, params) do
        super(format, module, type_ref, input, sp_type, params)
        |> Spectral.Codec.__convert_result__()
      end
    end
  end

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour Spectral.Codec
      @before_compile Spectral.Codec
    end
  end
end
