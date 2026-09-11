defmodule NestedDocBadExampleModule do
  @moduledoc false
  # An example that does not encode as its own type is rejected at every
  # position the type is inlined into (spectra 0.14.0)
  use Spectral

  spectral(title: "Count", examples: ["not an integer"])
  @type count :: non_neg_integer()

  @type wrapper :: %{count: count()}
end
