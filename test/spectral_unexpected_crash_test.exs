defmodule SpectralUnexpectedCrashTest do
  use ExUnit.Case, async: true

  @moduledoc """
  `Spectral.encode/decode/schema` rescue `error in ErlangError` to translate a few
  known spectra configuration errors (module/type not found, unsupported type) into
  `ArgumentError`. That rescue clause also binds every other BEAM error that Elixir
  normalizes into its own exception struct (e.g. `%KeyError{}`), not just literal
  `%ErlangError{}` structs. `handle_erlang_error/4` used to only pattern-match on
  `%ErlangError{}`, so those other exceptions crashed inside Spectral's own handler
  with a misleading `FunctionClauseError`, discarding the original exception and
  stacktrace. It must instead reraise the original exception with its original
  stacktrace.
  """

  test "encode reraises an unexpected crash unchanged, not as a FunctionClauseError" do
    error =
      assert_raise KeyError, fn ->
        Spectral.encode("data", CrashingCodec, :t)
      end

    assert %KeyError{key: :missing_key} = error

    stacktrace =
      try do
        Spectral.encode("data", CrashingCodec, :t)
      rescue
        _ -> __STACKTRACE__
      end

    assert Enum.any?(stacktrace, fn {mod, _fun, _arity, _location} -> mod == CrashingCodec end)
  end

  test "decode reraises an unexpected crash unchanged, not as a FunctionClauseError" do
    error =
      assert_raise KeyError, fn ->
        Spectral.decode("data", CrashingCodec, :t)
      end

    assert %KeyError{key: :missing_key} = error
  end

  test "schema/2 reraises an unexpected crash unchanged, not as a FunctionClauseError" do
    error =
      assert_raise KeyError, fn ->
        Spectral.schema(CrashingCodec, :t)
      end

    assert %KeyError{key: :missing_key} = error
  end

  test "schema/4 reraises an unexpected crash unchanged, not as a FunctionClauseError" do
    error =
      assert_raise KeyError, fn ->
        Spectral.schema(CrashingCodec, :t, :json_schema, [])
      end

    assert %KeyError{key: :missing_key} = error
  end

  test "an ErlangError with an unrecognized original is reraised unchanged, with its original stacktrace" do
    error =
      assert_raise ErlangError, fn ->
        Spectral.encode("data", CrashingCodec, :t2)
      end

    assert %ErlangError{original: {:unexpected_codec_failure, :detail}} = error

    stacktrace =
      try do
        Spectral.encode("data", CrashingCodec, :t2)
      rescue
        _ -> __STACKTRACE__
      end

    assert Enum.any?(stacktrace, fn {mod, _fun, _arity, _location} -> mod == CrashingCodec end)
  end
end
