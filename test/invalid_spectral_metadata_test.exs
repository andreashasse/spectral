defmodule InvalidSpectralMetadataTest do
  use ExUnit.Case

  test "spectral with invalid metadata (string) raises clear error" do
    assert_raise ArgumentError, ~r/spectral macro requires a keyword list or map/, fn ->
      Code.compile_string("""
      defmodule TestInvalidString do
        use Spectral

        spectral "invalid string"
        @type t :: atom()
      end
      """)
    end
  end

  test "spectral with invalid metadata (atom) raises clear error" do
    assert_raise ArgumentError, ~r/spectral macro requires a keyword list or map/, fn ->
      Code.compile_string("""
      defmodule TestInvalidAtom do
        use Spectral

        spectral :invalid_atom
        @type t :: atom()
      end
      """)
    end
  end

  test "spectral with invalid metadata (number) raises clear error" do
    assert_raise ArgumentError, ~r/spectral macro requires a keyword list or map/, fn ->
      Code.compile_string("""
      defmodule TestInvalidNumber do
        use Spectral

        spectral 123
        @type t :: atom()
      end
      """)
    end
  end

  test "spectral with invalid metadata (tuple) raises clear error" do
    assert_raise ArgumentError, ~r/spectral macro requires a keyword list or map/, fn ->
      Code.compile_string("""
      defmodule TestInvalidTuple do
        use Spectral

        spectral {:not, :valid}
        @type t :: atom()
      end
      """)
    end
  end

  test "spectral with valid keyword list works" do
    result =
      Code.compile_string("""
      defmodule TestValidKeywordList do
        use Spectral

        spectral title: "Valid", description: "Works fine"
        @type t :: atom()
      end
      """)

    assert [{TestValidKeywordList, _bytecode}] = result
  end

  test "spectral with valid map works" do
    result =
      Code.compile_string("""
      defmodule TestValidMap do
        use Spectral

        spectral %{title: "Valid", description: "Works fine"}
        @type t :: atom()
      end
      """)

    assert [{TestValidMap, _bytecode}] = result
  end

end
