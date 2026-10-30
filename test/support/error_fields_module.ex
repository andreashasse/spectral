defmodule ErrorFieldsModule do
  @moduledoc false
  use Spectral

  defstruct [:id, :kind]

  spectral(type_parameters: %{pattern: "^item_[a-z0-9]+$", min_length: 6, max_length: 20})
  @type item_id :: String.t()

  @type kind :: :small | :large

  @type t :: %ErrorFieldsModule{id: item_id(), kind: kind()}

  defmodule Contact do
    @moduledoc false
    use Spectral

    defstruct [:email]

    @type t :: %Contact{email: String.t()}
  end
end
