defmodule NilFieldsModule do
  @moduledoc """
  Structs with nullable fields, a nested struct and a list of structs, for nil_fields tests.
  """
  use Spectral

  defmodule Item do
    @moduledoc false
    use Spectral

    defstruct [:label, :count]

    @type t :: %Item{
            label: String.t(),
            count: integer() | nil
          }
  end

  defstruct [:name, :note, :child, :items, :active]

  @type t :: %NilFieldsModule{
          name: String.t(),
          note: String.t() | nil,
          child: Item.t() | nil,
          items: [Item.t()],
          active: boolean()
        }

  @type labels :: [String.t() | nil]
end
