defmodule BoundedSpecModule do
  @moduledoc false
  use Spectral

  @type t :: integer()

  # Bounded spec: var `a` appears nested inside list(a) and map(atom(), a)
  @spec identity(a) :: a when a: integer()
  def identity(x), do: x

  @spec wrap(a) :: [a] when a: integer()
  def wrap(x), do: [x]

  @spec head([a]) :: a when a: integer()
  def head([h | _]), do: h
end
