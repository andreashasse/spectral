defmodule MultiTypeModule do
  @moduledoc """
  Test module with two types where only one has @spectral attribute.
  This verifies that types without @spectral work correctly alongside types with @spectral.
  """
  use Spectral

  defstruct [:id, :value]

  @spectral %{title: "Main Type", description: "This is the documented type"}
  @type main_type :: %__MODULE__{
          id: non_neg_integer(),
          value: String.t()
        }

  # This type has no @spectral attribute
  @type other_type :: %__MODULE__{
          id: non_neg_integer() | nil,
          value: String.t() | nil
        }
end
