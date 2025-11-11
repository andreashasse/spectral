defmodule Person do
  defmodule Address do
    defstruct [:street, :city]

    @type t :: %Address{
            street: String.t(),
            city: String.t()
          }
  end

  defstruct [:name, :age, :address]

  @type t :: %Person{
          name: String.t(),
          age: non_neg_integer() | nil,
          address: Address.t() | nil
        }

  def testdata() do
    %Person{name: "Alice", age: 30}
  end

  def testjson() do
    ~s({"name":"Alice","age":30})
  end
end
