defmodule CodecRefModule do
  @moduledoc """
  A codec that drives every recursive call with a `{:type, name, arity}` reference
  rather than a resolved type node, and whose `schema/5` declines the types it does
  not own.
  """
  use Spectral.Codec
  use Spectral

  defmodule Inner do
    @moduledoc false
    use Spectral

    defstruct [:name]

    @type t :: %Inner{name: String.t()}
  end

  @type outer :: Inner.t()

  # Not handled by the codec. Every callback must decline it.
  @type plain :: integer()

  # A `{:record, name}` reference is the other half of `sp_type_reference()`.
  @type record_ref :: term()

  @impl Spectral.Codec
  def encode(format, _caller_type_info, {:type, :outer, 0}, _target_type, data, config) do
    Spectral.Codec.encode(format, Inner.__spectra_type_info__(), {:type, :t, 0}, data, config)
  end

  def encode(_format, _caller_type_info, _type_ref, _target_type, _data, _config), do: :continue

  @impl Spectral.Codec
  def decode(format, _caller_type_info, {:type, :outer, 0}, _target_type, input, config) do
    Spectral.Codec.decode(format, Inner.__spectra_type_info__(), {:type, :t, 0}, input, config)
  end

  def decode(_format, _caller_type_info, _type_ref, _target_type, _input, _config), do: :continue

  @impl Spectral.Codec
  def schema(:json_schema, _caller_type_info, {:type, :outer, 0}, _target_type, config) do
    Spectral.Codec.schema(:json_schema, Inner.__spectra_type_info__(), {:type, :t, 0}, config)
  end

  def schema(:json_schema, _caller_type_info, {:type, :record_ref, 0}, _target_type, config) do
    # Built here rather than taken from a module because this project has no Erlang
    # source, so no compiled module carries a record for the helper to look up.
    type_info =
      Spectral.TypeInfo.new(:nomodule, false)
      |> Spectral.TypeInfo.add_record(:point, {:sp_rec, :point, [], 1, %{}})

    Spectral.Codec.schema(:json_schema, type_info, {:record, :point}, config)
  end

  def schema(_format, _caller_type_info, _type_ref, _target_type, _config), do: :continue
end
