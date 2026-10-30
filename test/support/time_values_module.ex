defmodule TimeValuesModule do
  @moduledoc false
  use Spectral

  defstruct [:naive, :time, :maybe_naive, :maybe_time]

  @type t :: %TimeValuesModule{
          naive: NaiveDateTime.t(),
          time: Time.t(),
          maybe_naive: NaiveDateTime.t() | nil,
          maybe_time: Time.t() | nil
        }
end
