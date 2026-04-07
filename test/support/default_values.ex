defmodule DefaultValues.Config do
  @moduledoc false
  use Spectral

  # Both fields have non-nil defaults and non-nullable types.
  # timeout or retries missing from JSON → struct defaults fill them in.
  defstruct timeout: 30, retries: 3

  @type t :: %DefaultValues.Config{
          timeout: pos_integer(),
          retries: non_neg_integer()
        }
end

defmodule DefaultValues do
  @moduledoc false
  use Spectral

  # name:   nil default,   String.t()                   (non-nullable) → error when missing
  # score:  100 default,   non_neg_integer()             (non-nullable) → struct default when missing
  # active: true default,  boolean() | nil               (nullable)     → struct default when missing, NOT nil
  # config: struct default, DefaultValues.Config.t()    (non-nullable) → struct default when missing
  defstruct name: nil,
            score: 100,
            active: true,
            config: %DefaultValues.Config{timeout: 30, retries: 3}

  @type t :: %DefaultValues{
          name: String.t(),
          score: non_neg_integer(),
          active: boolean() | nil,
          config: DefaultValues.Config.t()
        }

  # Expose only name and active; score and config are excluded and filled from struct defaults.
  spectral(only: [:name, :active])

  @type public_t :: %DefaultValues{
          name: String.t(),
          score: non_neg_integer(),
          active: boolean() | nil,
          config: DefaultValues.Config.t()
        }
end
