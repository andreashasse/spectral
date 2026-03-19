defmodule SpectralAllElixirModulesTest do
  use ExUnit.Case, async: true

  @moduledoc false

  # Mirrors spectra's not_handled_modules_test/0, which runs
  # spectra_abstract_code:types_in_module/1 over every loaded module.
  # spectra's test covers modules loaded in the Erlang release; this one
  # also covers Elixir modules, which produce BEAM abstract code patterns
  # that Erlang code never generates (protocol dispatch tables,
  # macro-generated specs, anonymous function specs, etc.).
  test "TypeInfo.new/2 does not crash on any loaded module" do
    all_modules = Enum.map(:code.all_loaded(), fn {module, _} -> module end)

    errors =
      for module <- all_modules,
          result = try_new(module),
          result != :ok,
          do: {module, result}

    assert errors == [], format_errors(errors)
  end

  defp try_new(module) do
    Spectral.TypeInfo.new(module, false)
    :ok
  catch
    # Expected: module has no debug info or BEAM chunk is unreadable
    :error, {:beam_lib_error, _, _} -> :ok
    :error, {:module_types_not_found, _, _} -> :ok
    class, reason -> {class, reason}
  end

  defp format_errors(errors) do
    lines =
      Enum.map(errors, fn {mod, {class, reason}} ->
        "  #{inspect(mod)}: #{class} #{inspect(reason)}"
      end)

    "Unexpected errors on #{length(errors)} module(s):\n#{Enum.join(lines, "\n")}"
  end
end
