defmodule TypeWithParams do
  @moduledoc """
  Test module to verify types with parameters work correctly.
  """
  use Spectral

  spectral(title: "Generic", description: "A generic type")
  @type generic(t) :: {:ok, t}
end
