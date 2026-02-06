defmodule MultiTypeModuleReversed do
  @moduledoc """
  Test module with two types where the second type has @spectral attribute with docs.
  This verifies that @spectral attributes are correctly paired with types by order,
  and that an empty @spectral doesn't add title/description fields.
  """
  use Spectral

  defstruct [:id, :value]

  # Empty @spectral for the first type - no title/description
  @spectral %{}
  @type first_type :: %__MODULE__{
          id: non_neg_integer(),
          value: String.t()
        }

  @spectral %{title: "Second Type", description: "This is the documented second type"}
  @type second_type :: %__MODULE__{
          id: non_neg_integer() | nil,
          value: String.t() | nil
        }
end
