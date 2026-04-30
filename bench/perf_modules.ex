defmodule Perf.Address do
  defstruct [:street, :city, :zip_code, :country, :state, :type, :coordinates, :notes]

  @type address_type :: :home | :work | :billing | :shipping

  @type coordinates :: %{required(:lat) => float(), required(:lng) => float()}

  @type t :: %Perf.Address{
          street: String.t(),
          city: String.t(),
          zip_code: String.t(),
          country: String.t(),
          state: String.t() | nil,
          type: address_type(),
          coordinates: coordinates() | nil,
          notes: [String.t()]
        }
end

defmodule Perf.User do
  use Spectral

  defstruct [
    :id,
    :username,
    :email,
    :role,
    :status,
    :age,
    :score,
    :tags,
    :permissions,
    :metadata,
    :created_at,
    :last_seen,
    :phone,
    :addresses,
    :tag_scores
  ]

  @type role :: :admin | :editor | :viewer | :moderator

  @type status :: :active | :inactive | :suspended | :pending

  @type permission ::
          :read
          | :write
          | :delete
          | :admin
          | :publish
          | :deploy
          | :billing
          | :moderate
          | :ban_user
          | :audit

  spectral type_parameters: %{pattern: "^[a-z0-9._%+\\-]+@[a-z0-9.\\-]+\\.[a-z]{2,}$"}
  @type email :: String.t()

  @type tag_scores :: %{String.t() => integer()}

  spectral title: "User", description: "A platform user with addresses and activity metadata"
  @type t :: %Perf.User{
          id: pos_integer(),
          username: String.t(),
          email: email(),
          role: role(),
          status: status(),
          age: non_neg_integer() | nil,
          score: float(),
          tags: MapSet.t(String.t()),
          permissions: [permission()],
          metadata: %{String.t() => String.t()},
          created_at: DateTime.t(),
          last_seen: DateTime.t() | nil,
          phone: String.t() | nil,
          addresses: [Perf.Address.t()],
          tag_scores: tag_scores()
        }

  @type users :: [t()]
end
