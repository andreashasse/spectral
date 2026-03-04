defmodule MultiSpectralHandler do
  @moduledoc """
  Test module demonstrating edge cases in spectral/1 macro pairing:
  - A single annotation before multiple guarded @spec overloads for the same {name, arity}
  - Two annotations before the same @spec (last one wins)
  """
  use Spectral

  # A single @spectral covers both guarded @spec overloads for process/1
  spectral(summary: "Process item", description: "Handles both integers and binaries")

  @spec process(t) :: {:ok, integer()} when t: integer()
  @spec process(t) :: {:ok, binary()} when t: binary()
  def process(item) when is_integer(item), do: {:ok, item}
  def process(item) when is_binary(item), do: {:ok, item}

  # Two @spectral annotations before the same @spec — last one wins
  spectral(summary: "First annotation")
  spectral(summary: "Second annotation wins")

  @spec update(map()) :: map()
  def update(params), do: params
end
