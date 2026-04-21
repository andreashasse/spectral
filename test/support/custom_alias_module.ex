defmodule CustomAliasModule do
  @moduledoc false
  use Spectral

  # alias with custom as: — the short name used in the type should be :Addr, not :Address
  alias Person.Address, as: Addr

  defstruct [:name, :addr]

  @type t :: %CustomAliasModule{
          name: String.t(),
          addr: Addr.t() | nil
        }
end
