defmodule MultiTypeModuleFirstMissing do
  @moduledoc """
  Test module where the first type has no documentation and the second has documentation.
  This tests semantic pairing based on line numbers.
  """
  use Spectral

  defstruct [:id, :value]

  # First type - no documentation
  @type first_type :: %__MODULE__{
          id: non_neg_integer(),
          value: String.t()
        }

  # Second type - has spectral documentation
  spectral(title: "Second Type", description: "This is the documented second type")

  @type second_type :: %__MODULE__{
          id: non_neg_integer() | nil,
          value: String.t() | nil
        }
end
