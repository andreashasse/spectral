defmodule MultiTypeModuleFirstMissing do
  @moduledoc """
  Test module where the first type has an empty @spectral and the second has documentation.
  This tests that you need one @spectral per @type, using empty maps for undocumented types.
  """
  use Spectral

  defstruct [:id, :value]

  # First type - empty @spectral (no documentation)
  @spectral %{}
  @type first_type :: %__MODULE__{
          id: non_neg_integer(),
          value: String.t()
        }

  # Second type - HAS @spectral attribute with documentation
  @spectral %{title: "Second Type", description: "This is the documented second type"}
  @type second_type :: %__MODULE__{
          id: non_neg_integer() | nil,
          value: String.t() | nil
        }
end
