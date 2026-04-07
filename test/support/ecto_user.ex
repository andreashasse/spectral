defmodule EctoUser do
  @moduledoc false

  # Simulates an Ecto schema with timestamps().
  # In a real Ecto schema, inserted_at and updated_at would be DateTime.t() | nil
  # and require the Spectral.Codec.DateTime codec. Here we use String.t() | nil
  # to keep the fixture self-contained while demonstrating the same behaviour:
  # nil default + nullable type → omitted on encode, nil on decode when absent.
  use Spectral

  defstruct name: nil, email: nil, inserted_at: nil, updated_at: nil

  @type t :: %EctoUser{
          name: String.t() | nil,
          email: String.t() | nil,
          inserted_at: String.t() | nil,
          updated_at: String.t() | nil
        }
end
