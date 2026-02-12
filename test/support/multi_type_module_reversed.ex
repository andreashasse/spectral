defmodule MultiTypeModuleReversed do
  @moduledoc """
  Test module with two types where the second type has documentation.
  This verifies that spectral documentation is correctly paired with types by line position.
  """
  use Spectral

  defstruct [:id, :value]

  # First type has no documentation
  @type first_type :: %__MODULE__{
          id: non_neg_integer(),
          value: String.t()
        }

  spectral(title: "Second Type", description: "This is the documented second type")

  @type second_type :: %__MODULE__{
          id: non_neg_integer() | nil,
          value: String.t() | nil
        }
end
