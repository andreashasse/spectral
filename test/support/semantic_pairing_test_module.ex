defmodule SemanticPairingTestModule do
  @moduledoc """
  Test module to verify semantic (line-based) pairing of spectral docs with types.

  This validates the critical bug fix: documentation should be paired based on
  source line position, not array index.

  Before the fix: spectral[0] would pair with type[0] by index, even if they
  weren't adjacent in source code.

  After the fix: each spectral call documents the first @type defined after it.
  """
  use Spectral

  # First type - NO spectral documentation
  @type undocumented :: atom()

  # Second type - HAS spectral documentation
  spectral(title: "Documented", description: "This type has docs")
  @type documented :: binary()
end
