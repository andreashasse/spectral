defmodule JsonbShapeCodec do
  @moduledoc """
  A codec that reads the discriminator and jumps straight to the matching
  variant, instead of letting the union try each alternative in turn.

  The declared type stays honest so that tooling which ignores the codec still
  sees the real shape of the data.
  """
  use Spectral.Codec
  use Spectral

  alias JsonbShapes.Circle
  alias JsonbShapes.Square

  @variants %{"circle" => Circle, "square" => Square}
  @variant_modules Map.values(@variants)
  @shape_ref {:type, :shape, 0}

  @type shape :: Circle.t() | Square.t()

  # An ordinary type in the same module. The codec returns `:continue` for it,
  # so spectra falls through to its built-in structural handling.
  @type note :: String.t()

  @impl Spectral.Codec
  def encode(format, _caller_type_info, @shape_ref, _target_type, %mod{} = data, config)
      when mod in @variant_modules do
    {type_info, type} = variant_type(mod)
    Spectral.Codec.encode(format, type_info, type, data, config)
  end

  def encode(_format, _caller_type_info, @shape_ref, _target_type, data, _config) do
    mismatch(data)
  end

  def encode(_format, _caller_type_info, _type_ref, _target_type, _data, _config), do: :continue

  @impl Spectral.Codec
  def decode(
        format,
        _caller_type_info,
        @shape_ref,
        _target_type,
        %{"kind" => kind} = input,
        config
      )
      when is_map_key(@variants, kind) do
    {type_info, type} = variant_type(Map.fetch!(@variants, kind))
    Spectral.Codec.decode(format, type_info, type, input, config)
  end

  def decode(_format, _caller_type_info, @shape_ref, _target_type, input, _config) do
    mismatch(input)
  end

  def decode(_format, _caller_type_info, _type_ref, _target_type, _input, _config), do: :continue

  @impl Spectral.Codec
  def schema(:json_schema, _caller_type_info, @shape_ref, _target_type, config) do
    %{
      oneOf:
        Enum.map(@variant_modules, fn mod ->
          {type_info, type} = variant_type(mod)
          Spectral.Codec.schema(:json_schema, type_info, type, config)
        end)
    }
  end

  # Without this clause, generating a schema for any other type in this module
  # raises. The `schema/5` callback is declared to return a map, but spectra
  # also accepts `:continue` and falls through to its structural schema.
  def schema(_format, _caller_type_info, _type_ref, _target_type, _config), do: :continue

  defp mismatch(value) do
    {:error,
     [
       %Spectral.Error{
         type: :type_mismatch,
         location: [],
         context: %{type: @shape_ref, value: value}
       }
     ]}
  end

  # Recursive codec calls take a resolved type node, not a {:type, name, arity}
  # reference, so look the variant's `t/0` up in its own type_info.
  defp variant_type(mod) do
    type_info = mod.__spectra_type_info__()
    {type_info, Spectral.TypeInfo.get_type(type_info, :t, 0)}
  end
end
