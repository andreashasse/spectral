defmodule MultiTypeModule do
  @moduledoc """
  Test module with two types where only one has spectral documentation.
  This verifies that types without documentation work correctly alongside documented types.
  """
  use Spectral

  defstruct [:id, :value]

  spectral(title: "Main Type", description: "This is the documented type")

  @type main_type :: %__MODULE__{
          id: non_neg_integer(),
          value: String.t()
        }

  # This type has no spectral documentation
  @type other_type :: %__MODULE__{
          id: non_neg_integer() | nil,
          value: String.t() | nil
        }
end
