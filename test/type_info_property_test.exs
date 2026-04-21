defmodule TypeInfoPropertyTest do
  @moduledoc false
  use ExUnit.Case, async: false
  use ExUnitProperties

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp functions_map(type_info), do: elem(type_info, 4)

  defp strip_injected_specs(type_info) do
    fns = functions_map(type_info) |> Map.reject(fn {{name, _}, _} -> name == :__info__ end)
    put_elem(type_info, 4, fns)
  end

  defp runtime_type_info(mod) do
    beam_path = Path.join(System.tmp_dir!(), "#{mod}.beam")
    ti = :spectra_abstract_code.types_in_module_path(String.to_charlist(beam_path))
    strip_injected_specs(ti)
  end

  defp unique_module_name do
    :"Elixir.PropTest#{System.unique_integer([:positive])}"
  end

  defp compile_module(name, type_def) do
    code = """
    defmodule #{inspect(name)} do
      use Spectral
      #{type_def}
    end
    """

    # mix test sets debug_info: false; force it on so beam contains abstract_code
    prev = Code.compiler_options()[:debug_info]
    Code.put_compiler_option(:debug_info, true)

    compiled =
      try do
        Code.compile_string(code, "nofile")
      after
        Code.put_compiler_option(:debug_info, prev)
      end

    {^name, beam_binary} = List.keyfind!(compiled, name, 0)

    # Write to disk so spectra_abstract_code.types_in_module_path/1 can read it
    beam_path = Path.join(System.tmp_dir!(), "#{name}.beam")
    File.write!(beam_path, beam_binary)
    :ok
  end

  defp cleanup_module(name) do
    beam_path = Path.join(System.tmp_dir!(), "#{name}.beam")
    File.rm(beam_path)
    :code.purge(name)
    :code.delete(name)
  end

  # ---------------------------------------------------------------------------
  # Generators
  # ---------------------------------------------------------------------------

  defp simple_type_str do
    StreamData.member_of([
      "integer()",
      "binary()",
      "atom()",
      "boolean()",
      "float()",
      "String.t()",
      "term()",
      "number()",
      "pid()",
      "reference()",
      "non_neg_integer()",
      "pos_integer()",
      "iodata()",
      "nil"
    ])
  end

  defp type_def_gen do
    StreamData.one_of([
      # Simple type
      StreamData.map(simple_type_str(), &"@type t :: #{&1}"),
      # Union of two
      StreamData.map(
        StreamData.tuple({simple_type_str(), simple_type_str()}),
        fn {a, b} -> "@type t :: #{a} | #{b}" end
      ),
      # Union with nil
      StreamData.map(simple_type_str(), &"@type t :: #{&1} | nil"),
      # List
      StreamData.map(simple_type_str(), &"@type t :: [#{&1}]"),
      # Tuple of two
      StreamData.map(
        StreamData.tuple({simple_type_str(), simple_type_str()}),
        fn {a, b} -> "@type t :: {#{a}, #{b}}" end
      ),
      # Optional map field
      StreamData.map(
        StreamData.tuple({simple_type_str(), simple_type_str()}),
        fn {k, v} -> "@type t :: %{optional(atom()) => #{v}}\n@type key :: #{k}" end
      ),
      # Multiple types
      StreamData.map(
        StreamData.tuple({simple_type_str(), simple_type_str()}),
        fn {a, b} -> "@type t :: #{a}\n@type other :: #{b}" end
      )
    ])
  end

  # ---------------------------------------------------------------------------
  # Properties
  # ---------------------------------------------------------------------------

  property "compile-time type_info matches runtime for generated modules" do
    check all(type_def <- type_def_gen(), max_runs: 50) do
      mod = unique_module_name()

      try do
        compile_module(mod, type_def)

        compile_time = mod.__spectra_type_info__()
        runtime = runtime_type_info(mod)

        assert compile_time == runtime,
               """
               Mismatch for generated module with type_def:
                 #{type_def}

               Compile-time: #{inspect(compile_time, pretty: true)}
               Runtime:      #{inspect(runtime, pretty: true)}
               """
      after
        cleanup_module(mod)
      end
    end
  end

  property "compile-time type_info has correct module name" do
    check all(type_def <- type_def_gen(), max_runs: 20) do
      mod = unique_module_name()

      try do
        compile_module(mod, type_def)
        ti = mod.__spectra_type_info__()
        assert :spectra_type_info.get_module(ti) == mod
      after
        cleanup_module(mod)
      end
    end
  end

  property "type count in compile-time type_info matches @type count" do
    check all(
            types <-
              StreamData.list_of(simple_type_str(),
                min_length: 1,
                max_length: 5
              ),
            max_runs: 20
          ) do
      mod = unique_module_name()

      type_defs =
        types
        |> Enum.with_index(1)
        |> Enum.map_join("\n", fn {t, i} -> "@type t#{i} :: #{t}" end)

      try do
        compile_module(mod, type_defs)
        ti = mod.__spectra_type_info__()
        type_count = elem(ti, 2) |> map_size()
        assert type_count == length(types)
      after
        cleanup_module(mod)
      end
    end
  end
end
