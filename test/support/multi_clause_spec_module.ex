defmodule MultiClauseSpecModule do
  @moduledoc false
  use Spectral

  @type t :: integer()

  # Multi-clause spec — compile-time must produce clauses in source order
  @spec classify(integer()) :: :int
  @spec classify(binary()) :: :bin
  @spec classify(atom()) :: :atom
  def classify(x) when is_integer(x), do: :int
  def classify(x) when is_binary(x), do: :bin
  def classify(x) when is_atom(x), do: :atom
end
