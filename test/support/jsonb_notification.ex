defmodule JsonbNotification do
  @moduledoc """
  Payloads for a JSONB column whose type is decided by a sibling column.

  Nothing inside the document says which variant it is, so the type reference
  has to be supplied at call time. Each type is named after the value stored in
  the discriminator column, which lets the caller pass that value straight
  through as the `type_ref` argument.
  """
  use Spectral

  defmodule Email do
    @moduledoc false
    use Spectral

    defstruct [:to, :subject]

    @type t :: %Email{to: String.t(), subject: String.t()}
  end

  defmodule Sms do
    @moduledoc false
    use Spectral

    defstruct [:number, :body]

    @type t :: %Sms{number: String.t(), body: String.t()}
  end

  @type email :: Email.t()
  @type sms :: Sms.t()
end
