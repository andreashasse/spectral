defmodule NonemptyListModule do
  @moduledoc false
  use Spectral

  @type shorthand :: %{tags: [String.t(), ...]}
  @type longhand :: %{tags: nonempty_list(String.t())}
end
