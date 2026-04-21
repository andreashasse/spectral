defmodule AllTypesModule do
  @moduledoc false

  use Spectral

  defstruct [:id, :name]

  # Simple built-in types
  @type t_integer :: integer()
  @type t_binary :: binary()
  @type t_atom :: atom()
  @type t_boolean :: boolean()
  @type t_float :: float()
  @type t_number :: number()
  @type t_term :: term()
  @type t_any :: any()
  @type t_pid :: pid()
  @type t_port :: port()
  @type t_reference :: reference()
  @type t_iodata :: iodata()
  @type t_iolist :: iolist()
  @type t_bitstring :: bitstring()
  @type t_node :: node()
  @type t_module :: module()

  # Integer range subtypes
  @type t_non_neg :: non_neg_integer()
  @type t_pos :: pos_integer()
  @type t_neg :: neg_integer()

  # Special integer range types
  @type t_arity :: arity()
  @type t_byte :: byte()
  @type t_char :: char()

  # Explicit range
  @type t_range :: 0..255
  @type t_neg_range :: -10..-1

  # Literal values
  @type t_literal_atom :: :hello
  @type t_literal_nil :: nil
  @type t_literal_true :: true
  @type t_literal_false :: false
  @type t_literal_int :: 42

  # Union types
  @type t_union2 :: integer() | binary()
  @type t_union3 :: integer() | binary() | nil
  @type t_union_lit :: :ok | :error
  @type t_optional :: integer() | nil

  # List types
  @type t_list_any :: list()
  @type t_list_typed :: list(integer())
  @type t_list_shorthand :: [atom()]
  @type t_nonempty_list :: nonempty_list(integer())
  @type t_nonempty_list_any :: nonempty_list()

  # Tuple types
  @type t_tuple_any :: tuple()
  @type t_tuple2 :: {atom(), integer()}
  @type t_tuple3 :: {atom(), integer(), binary()}

  # Map types
  @type t_map_any :: map()
  @type t_map_typed :: %{atom() => integer()}
  @type t_map_required :: %{required(:name) => String.t(), required(:age) => integer()}
  @type t_map_optional :: %{optional(:label) => binary()}
  @type t_map_mixed :: %{required(:id) => integer(), optional(:tag) => atom()}

  # Struct types
  @type t :: %AllTypesModule{id: integer() | nil, name: String.t() | nil}

  # Remote types
  @type t_string :: String.t()
  @type t_keyword :: keyword()
  @type t_keyword_typed :: keyword(integer())

  # User-defined type references
  @type t_user_ref :: t_integer()
  @type t_user_ref_union :: t_atom() | t_binary()

  # Parameterized types
  @type t_param(a) :: list(a)
  @type t_param2(a, b) :: {a, b}

  # Special compound types
  @type t_timeout :: timeout()
  @type t_mfa :: mfa()
  @type t_identifier :: identifier()

  # Function types
  @type t_fun_any :: fun()
  @type t_fun_typed :: (integer() -> binary())

  # maybe_improper_list and nonempty_improper_list
  @type t_maybe_improper :: maybe_improper_list()
  @type t_maybe_improper_typed :: maybe_improper_list(integer(), binary())
  @type t_nonempty_improper :: nonempty_improper_list(atom(), binary())
end
