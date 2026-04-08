defmodule OnlyPerson do
  @moduledoc false
  use Spectral

  defstruct [:name, :age, :email]

  spectral(only: [:name, :age])

  @type t :: %OnlyPerson{
          name: String.t(),
          age: non_neg_integer() | nil,
          email: String.t() | nil
        }

  spectral(only: [:name, :age])

  @type t_or_nil ::
          %OnlyPerson{
            name: String.t(),
            age: non_neg_integer() | nil,
            email: String.t() | nil
          }
          | nil
end
