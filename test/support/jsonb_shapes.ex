defmodule JsonbShapes do
  @moduledoc """
  Self-describing payloads for a JSONB column: the discriminator lives inside
  the JSON document, so the column has a single static type.

  Each variant pins its `kind` field to a literal atom. That literal is what
  makes the union unambiguous when spectra tries the alternatives in order.
  """
  use Spectral

  defmodule Circle do
    @moduledoc false
    use Spectral

    defstruct [:kind, :radius]

    @type t :: %Circle{kind: :circle, radius: float()}
  end

  defmodule Square do
    @moduledoc false
    use Spectral

    defstruct [:kind, :side]

    @type t :: %Square{kind: :square, side: float()}
  end

  spectral(title: "Shape", description: "A shape stored in a JSONB column")

  @type shape :: Circle.t() | Square.t()
end

defmodule JsonbUntaggedShapes do
  @moduledoc """
  The same union without a discriminator field, kept to pin down the failure
  mode documented in the README: unions are first-match-wins and extra JSON
  keys are ignored, so a variant whose fields are a subset of another's
  swallows payloads meant for the later variant.
  """
  use Spectral

  defmodule Name do
    @moduledoc false
    use Spectral

    defstruct [:name]

    @type t :: %Name{name: String.t()}
  end

  defmodule NameAndSize do
    @moduledoc false
    use Spectral

    defstruct [:name, :size]

    @type t :: %NameAndSize{name: String.t(), size: integer()}
  end

  @type payload :: Name.t() | NameAndSize.t()
end
