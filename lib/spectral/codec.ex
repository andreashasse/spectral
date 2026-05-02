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
        def encode(_format, _caller_type_info, {:type, :point, 0}, _target_type, {x, y}, _config)
            when is_number(x) and is_number(y) do
          {:ok, [x, y]}
        end

        def encode(_format, _caller_type_info, {:type, :point, 0}, _target_type, data, _config) do
          {:error, [%Spectral.Error{type: :type_mismatch, location: [], context: %{type: {:type, :point, 0}, value: data}}]}
        end

        # Types not handled by this codec → continue to default
        def encode(_format, _caller_type_info, _type_ref, _target_type, _data, _config), do: :continue

        @impl Spectral.Codec
        def decode(_format, _caller_type_info, {:type, :point, 0}, _target_type, [x, y], _config)
            when is_number(x) and is_number(y) do
          {:ok, {x, y}}
        end

        def decode(_format, _caller_type_info, {:type, :point, 0}, _target_type, data, _config) do
          {:error, [%Spectral.Error{type: :type_mismatch, location: [], context: %{type: {:type, :point, 0}, value: data}}]}
        end

        def decode(_format, _caller_type_info, _type_ref, _target_type, _input, _config), do: :continue

        @impl Spectral.Codec
        def schema(:json_schema, _caller_type_info, {:type, :point, 0}, _target_type, _config) do
          %{type: "array", items: %{type: "number"}, minItems: 2, maxItems: 2}
        end
      end

  ## The `target_type` argument

  The fourth argument to `encode/6`, `decode/6`, and `schema/5` is the `sp_type()`
  instantiation node from the type traversal. For generic types (those with type
  variables, such as `MapSet.t(elem)`) this is the reference node and carries the
  concrete type-variable bindings of the current instantiation. Use
  `Spectral.Type.type_args/1` to extract them for recursive encoding/decoding.

  For non-generic types this argument is the resolved type definition and
  `Spectral.Type.type_args/1` returns `[]`.

  ## Return Values

  - `{:ok, result}` — Use this result instead of the default
  - `{:error, errors}` — The data is invalid for a type this codec handles; `errors`
    is a list of `%Spectral.Error{}` structs
  - `:continue` — This codec does not handle this type; fall through to spectra's
    built-in structural codec

  The distinction between `{:error, ...}` and `:continue` matters: return `{:error, ...}`
  when the data has the wrong shape for a type your codec *owns*, and `:continue` for
  type references your codec does not recognise at all.

  ## Recursive Calls

  When your codec handles a container type and needs to encode or decode its elements
  according to their types, use the helper functions on this module rather than calling
  `Spectral.encode/5` or `Spectral.decode/5`. The helpers preserve the runtime `config`
  (cache mode, codec registry, format) across the traversal; the public `Spectral` API
  would start a fresh traversal and lose that context.

      @impl Spectral.Codec
      def encode(format, caller_type_info, {:type, :wrapper, 1}, target_type, %Wrapper{value: v}, config) do
        case Spectral.Type.type_args(target_type) do
          [elem_type] ->
            case Spectral.Codec.encode(format, caller_type_info, elem_type, v, config) do
              {:ok, encoded} -> {:ok, %{"value" => encoded}}
              error -> error
            end
          [] -> {:ok, %{"value" => v}}
        end
      end

  Use `Spectral.Type.type_args/1` to extract the concrete type arguments from `target_type`
  when handling generic types (see the `target_type` section above).

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
  Recursively encodes `data` of `type_ref` inside a codec callback.

  Pass the `format` and `caller_type_info` received in your `encode/6` callback.
  Preserves the runtime `config` (cache mode, codecs) across the traversal,
  unlike `Spectral.encode/5` which starts a fresh traversal.

  Returns `{:ok, term()}` (a pre-encoded term) or `{:error, [Spectral.Error.t()]}`.
  """
  @spec encode(atom(), Spectral.type_info(), Spectral.sp_type_or_ref(), term(), term()) ::
          {:ok, term()} | {:error, [Spectral.Error.t()]}
  def encode(format, type_info, type_ref, data, config) do
    result =
      case format do
        :json ->
          :spectra_json.to_json(type_info, type_ref, data, config)

        :binary_string ->
          :spectra_binary_string.to_binary_string(type_info, type_ref, data, %{}, config)

        :string ->
          :spectra_string.to_string(type_info, type_ref, data, config)
      end

    case result do
      {:ok, _} = ok -> ok
      {:error, errors} -> {:error, Spectral.Error.from_erlang_list(errors)}
    end
  end

  @doc """
  Recursively decodes `input` to `type_ref` inside a codec callback.

  Pass the `format` and `caller_type_info` received in your `decode/6` callback.
  Preserves the runtime `config` (cache mode, codecs) across the traversal,
  unlike `Spectral.decode/5` which starts a fresh traversal.

  The `input` must already be a decoded term (JSON is pre-parsed by the time
  codec callbacks are invoked).

  Returns `{:ok, term()}` or `{:error, [Spectral.Error.t()]}`.
  """
  @spec decode(atom(), Spectral.type_info(), Spectral.sp_type_or_ref(), term(), term()) ::
          {:ok, term()} | {:error, [Spectral.Error.t()]}
  def decode(format, type_info, type_ref, input, config) do
    result =
      case format do
        :json ->
          :spectra_json.from_json(type_info, type_ref, input, config)

        :binary_string ->
          :spectra_binary_string.from_binary_string(type_info, type_ref, input, %{}, config)

        :string ->
          :spectra_string.from_string(type_info, type_ref, input, config)
      end

    case result do
      {:ok, _} = ok -> ok
      {:error, errors} -> {:error, Spectral.Error.from_erlang_list(errors)}
    end
  end

  @doc """
  Generates a schema map for `type_ref` inside a codec `schema/5` callback.

  Pass the `caller_type_info` received in your `schema/5` callback.
  Preserves the runtime `config` across the traversal. Returns a pre-encoded schema map.
  """
  @spec schema(atom(), Spectral.type_info(), Spectral.sp_type_or_ref(), term()) :: dynamic()
  def schema(:json_schema, type_info, type_ref, config) do
    :spectra_json_schema.to_schema(type_info, type_ref, config)
  end

  @doc """
  Encodes `data` of the given `target_type_ref` to `format`.

  Called by spectra when encoding a value whose type is defined in a codec module.
  Return `{:error, errors}` when the data is invalid for a type your codec handles,
  or `:continue` for types this codec does not recognise.

  `caller_type_info` is the type info of the module driving the traversal.
  `target_type` is the instantiation node from the type traversal; use
  `Spectral.Type.type_args/1` to extract type-variable bindings for generic types.
  Use `:spectra_type.parameters/1` on `target_type` to read `type_parameters` (only
  reliable when the codec is invoked directly from a `Spectral` entry point).
  `config` is the runtime config; pass `format` and `config` to `Spectral.Codec.encode/5`,
  `Spectral.Codec.decode/5`, and `Spectral.Codec.schema/4` for recursive calls within
  this callback.
  """
  @callback encode(
              format :: atom(),
              caller_type_info :: Spectral.type_info(),
              target_type_ref :: Spectral.sp_type_reference(),
              target_type :: Spectral.sp_type_or_ref(),
              data :: term(),
              config :: term()
            ) :: encode_result()

  @doc """
  Decodes `input` from `format` into the Elixir value described by `target_type_ref`.

  Called by spectra when decoding a value whose type is defined in a codec module.
  Return `{:error, errors}` when the input is invalid for a type your codec handles,
  or `:continue` for types this codec does not recognise.

  `caller_type_info` is the type info of the module driving the traversal.
  `target_type` is the instantiation node from the type traversal; use
  `Spectral.Type.type_args/1` to extract type-variable bindings for generic types.
  Use `:spectra_type.parameters/1` on `target_type` to read `type_parameters` (only
  reliable when the codec is invoked directly from a `Spectral` entry point).
  `config` is the runtime config; pass `format` and `config` to `Spectral.Codec.decode/5` for recursive calls.
  """
  @callback decode(
              format :: atom(),
              caller_type_info :: Spectral.type_info(),
              target_type_ref :: Spectral.sp_type_reference(),
              target_type :: Spectral.sp_type_or_ref(),
              input :: term(),
              config :: term()
            ) :: decode_result()

  @doc """
  Returns a schema map for `target_type_ref` in `format`.

  This callback is optional. If not implemented, spectra will raise
  `{:schema_not_implemented, module, type_ref}` when schema generation is requested
  for a type owned by this codec.

  `caller_type_info` is the type info of the module driving the traversal.
  `target_type` is the type node; use `:spectra_type.parameters/1` to read
  `type_parameters` (only reliable when invoked directly from a `Spectral` entry point).
  `config` is the runtime config; pass `format` and `config` to `Spectral.Codec.schema/4` for recursive calls.
  """
  @callback schema(
              format :: atom(),
              caller_type_info :: Spectral.type_info(),
              target_type_ref :: Spectral.sp_type_reference(),
              target_type :: Spectral.sp_type_or_ref(),
              config :: term()
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
      def encode(format, caller_type_info, target_type_ref, target_type, data, config) do
        super(format, caller_type_info, target_type_ref, target_type, data, config)
        |> Spectral.Codec.__convert_result__()
      end

      @impl Spectral.Codec
      def decode(format, caller_type_info, target_type_ref, target_type, input, config) do
        super(format, caller_type_info, target_type_ref, target_type, input, config)
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
