defmodule StringConstraintsModule do
  @moduledoc false
  use Spectral

  spectral(type_parameters: %{min_length: 2, max_length: 10})
  @type bounded :: String.t()

  spectral(type_parameters: %{pattern: "^[a-z]+$"})
  @type lowercase :: String.t()

  spectral(type_parameters: %{min_length: 1, format: "hostname"})
  @type annotated :: String.t()
end
