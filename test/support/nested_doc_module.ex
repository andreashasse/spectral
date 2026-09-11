defmodule NestedDocModule do
  @moduledoc false
  # Doc annotations propagate into inlined sub-schemas (spectra 0.14.0)
  use Spectral

  defmodule Remote do
    @moduledoc false
    use Spectral

    spectral(title: "Payer", description: "Account charged", deprecated: true)
    @type payer :: String.t()
  end

  spectral(title: "Amount", description: "Amount in cents", examples: [1500])
  @type amount :: non_neg_integer()

  spectral(title: "Tag", description: "A short tag")
  @type tag :: String.t()

  @type request :: %{
          payer: Remote.payer(),
          amount: amount(),
          tags: [tag()],
          more_tags: nonempty_list(tag()),
          note: tag() | integer()
        }

  @type optional_map :: %{optional(:tag) => tag()}

  defstruct [:amount, :tag]

  @type t :: %NestedDocModule{amount: amount(), tag: tag()}

  spectral(title: "Label")
  @type label :: tag()

  @type labelled :: %{label: label()}
end
