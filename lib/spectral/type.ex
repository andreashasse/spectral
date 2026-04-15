defmodule Spectral.Type do
  @moduledoc """
  Elixir wrapper for the Erlang `:spectra_type` module.

  Provides functions for inspecting `sp_type()` values. These are most useful
  inside `Spectral.Codec` callbacks, where the `sp_type` argument carries the
  instantiation node from the type traversal.

  > #### Advanced integrations {: .info}
  >
  > This module is intended for advanced integrations, such as building custom
  > web framework plugins or other tooling on top of Spectral. Most applications
  > will not need to use it directly.
  """

  @doc """
  Returns the concrete type-variable bindings for a generic `sp_type()` node.

  When a codec is invoked during type traversal for a parameterised type such as
  `MapSet.t(integer())` or `dict:dict(binary(), float())`, the `sp_type` argument
  is the reference node and `type_args/1` returns the list of concrete type
  arguments in declaration order.

  Returns `[]` when the type has no type variables, or when the codec is invoked
  directly from a `Spectral.encode/decode/schema` entry point rather than from
  mid-traversal dispatch.

  ## Example

      # In a codec for MapSet.t(elem):
      def encode(:json, mod, {:type, :t, 1}, %MapSet{} = ms, sp_type, _params, _config) do
        case Spectral.Type.type_args(sp_type) do
          [elem_type] ->
            # recursively encode each element using elem_type
          [] ->
            # no type info available, fall back to plain list
            {:ok, MapSet.to_list(ms)}
        end
      end
  """
  @spec type_args(term()) :: [term()]
  def type_args(sp_type) do
    :spectra_type.type_args(sp_type)
  end
end
