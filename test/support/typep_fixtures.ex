defmodule TestTypepWithSpectral do
  use Spectral

  spectral title: "Internal ID", description: "A private identifier"
  @typep internal_id :: non_neg_integer()
  @type t :: %{id: internal_id()}
end

defmodule TestTypepWithoutSpectral do
  use Spectral

  @typep internal_id :: non_neg_integer()
  @type t :: %{id: internal_id()}
end
