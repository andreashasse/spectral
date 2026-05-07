defmodule TypeRefModule do
  @moduledoc false
  # Tests for field_aliases and only propagation through type references (0.13.1)
  use Spectral

  defmodule Inner do
    @moduledoc false
    use Spectral

    defstruct [:first_name, :last_name, :secret]

    @type t :: %Inner{
            first_name: String.t() | nil,
            last_name: String.t() | nil,
            secret: String.t() | nil
          }
  end

  # field_aliases on a remote type reference (sp_remote_type)
  spectral(field_aliases: %{first_name: "firstName", last_name: "lastName"})
  @type aliased_t :: Inner.t()

  # only on a remote type reference
  spectral(only: [:first_name, :last_name])
  @type restricted_t :: Inner.t()

  # field_aliases + only on a remote type reference
  spectral(only: [:first_name, :last_name], field_aliases: %{first_name: "firstName"})
  @type restricted_aliased_t :: Inner.t()

  # field_aliases on a local user type ref (sp_user_type_ref)
  spectral(field_aliases: %{first_name: "firstName"})
  @type local_aliased_t :: aliased_t()
end
