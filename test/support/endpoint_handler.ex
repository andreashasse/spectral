defmodule EndpointHandler do
  @moduledoc """
  Test module demonstrating spectral/1 macro usage before function definitions.
  """
  use Spectral

  defstruct [:id, :name]

  spectral(title: "EndpointHandler", description: "A handler type")

  @type t :: %EndpointHandler{
          id: non_neg_integer(),
          name: String.t()
        }

  spectral(summary: "Get resource", description: "Returns a resource by ID")

  @spec get(map(), map()) :: map()
  def get(_conn, _params), do: %{}

  spectral(summary: "Create resource", description: "Creates a new resource", deprecated: false)

  @spec create(map(), map()) :: map()
  def create(_conn, _params), do: %{}

  @spec list(map()) :: [map()]
  def list(_conn), do: []
end
