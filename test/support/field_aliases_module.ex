defmodule FieldAliasesModule do
  @moduledoc false
  use Spectral

  defstruct [:first_name, :last_name, :birth_year]

  spectral(field_aliases: %{first_name: "firstName", last_name: "lastName"})

  @type t :: %FieldAliasesModule{
          first_name: String.t() | nil,
          last_name: String.t() | nil,
          birth_year: non_neg_integer() | nil
        }

  spectral(field_aliases: %{first_name: "firstName"}, only: [:first_name, :last_name])

  @type partial :: %FieldAliasesModule{
          first_name: String.t() | nil,
          last_name: String.t() | nil,
          birth_year: non_neg_integer() | nil
        }

  spectral(field_aliases: %{key: "camelKey"})

  @type map_t :: %{key: String.t()}
end
