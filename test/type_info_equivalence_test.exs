defmodule TypeInfoEquivalenceTest do
  @moduledoc false
  use ExUnit.Case, async: true

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # type_info tuple: {:type_info, module, types_map, records_map, functions_map, is_behaviour}
  defp types_map(type_info), do: elem(type_info, 2)
  defp functions_map(type_info), do: elem(type_info, 4)

  defp runtime_type_info(mod) do
    beam_path = :code.which(mod)
    ti = :spectra_abstract_code.types_in_module_path(beam_path)
    # Strip Elixir-injected __info__/1 spec — not present in compile-time path
    strip_injected_specs(ti)
  end

  defp strip_injected_specs(type_info) do
    fns = functions_map(type_info) |> Map.reject(fn {{name, _}, _} -> name == :__info__ end)
    type_info |> put_elem(4, fns)
  end

  defp type_names(type_info) do
    type_info
    |> types_map()
    |> Map.keys()
    |> Enum.sort()
  end

  defp function_keys(type_info) do
    type_info
    |> functions_map()
    |> Map.keys()
    |> Enum.sort()
  end

  # ---------------------------------------------------------------------------
  # AllTypesModule: full structural equality (no annotations, no specs)
  # ---------------------------------------------------------------------------

  test "AllTypesModule: compile-time type_info matches runtime" do
    compile_time = AllTypesModule.__spectra_type_info__()
    runtime = runtime_type_info(AllTypesModule)

    assert compile_time == runtime,
           """
           Mismatch for AllTypesModule.

           Compile-time types: #{inspect(Map.keys(types_map(compile_time)) |> Enum.sort())}
           Runtime types:      #{inspect(Map.keys(types_map(runtime)) |> Enum.sort())}

           Differing keys:
           #{diff_types(compile_time, runtime)}
           """
  end

  defp diff_types(ct, rt) do
    all_keys =
      (Map.keys(types_map(ct)) ++ Map.keys(types_map(rt)))
      |> Enum.uniq()
      |> Enum.sort()

    for key <- all_keys,
        Map.get(types_map(ct), key) != Map.get(types_map(rt), key) do
      "  #{inspect(key)}:\n    compile: #{inspect(Map.get(types_map(ct), key))}\n    runtime: #{inspect(Map.get(types_map(rt), key))}"
    end
    |> Enum.join("\n")
  end

  # ---------------------------------------------------------------------------
  # Annotated modules: check module identity and type/function name presence
  # (docs differ between compile-time and runtime so we only check names)
  # ---------------------------------------------------------------------------

  @annotated_modules [
    Person,
    Person.Address,
    MultiTypeModule,
    OnlyPerson,
    EndpointHandler,
    MultiSpectralHandler,
    SemanticPairingTestModule,
    DefaultValues,
    DefaultValues.Config
  ]

  for mod <- @annotated_modules do
    test "#{inspect(mod)}: compile-time type names match runtime" do
      mod = unquote(mod)
      compile_time = mod.__spectra_type_info__()
      runtime = runtime_type_info(mod)

      assert :spectra_type_info.get_module(compile_time) ==
               :spectra_type_info.get_module(runtime)

      assert type_names(compile_time) == type_names(runtime)
    end
  end

  # EndpointHandler has specs — check compile-time function keys match runtime
  test "EndpointHandler: compile-time function specs match runtime" do
    compile_time = EndpointHandler.__spectra_type_info__()
    runtime = runtime_type_info(EndpointHandler)

    assert function_keys(compile_time) == function_keys(runtime)
  end

  # ---------------------------------------------------------------------------
  # AllTypesModule spot checks
  # ---------------------------------------------------------------------------

  test "AllTypesModule: module name is correct" do
    ti = AllTypesModule.__spectra_type_info__()
    assert :spectra_type_info.get_module(ti) == AllTypesModule
  end

  test "AllTypesModule: all expected type names are present" do
    ti = AllTypesModule.__spectra_type_info__()
    names = ti |> type_names() |> Enum.map(&elem(&1, 0))

    expected = [
      :t,
      :t_integer,
      :t_binary,
      :t_atom,
      :t_boolean,
      :t_float,
      :t_number,
      :t_term,
      :t_any,
      :t_pid,
      :t_port,
      :t_reference,
      :t_iodata,
      :t_iolist,
      :t_non_neg,
      :t_pos,
      :t_neg,
      :t_range,
      :t_literal_atom,
      :t_literal_nil,
      :t_union2,
      :t_union3,
      :t_optional,
      :t_list_any,
      :t_list_typed,
      :t_list_shorthand,
      :t_nonempty_list,
      :t_tuple_any,
      :t_tuple2,
      :t_tuple3,
      :t_map_any,
      :t_map_typed,
      :t_string,
      :t_user_ref,
      :t_param,
      :t_param2,
      :t_timeout,
      :t_mfa,
      :t_fun_any,
      :t_fun_typed
    ]

    for name <- expected do
      assert name in names, "Expected type #{inspect(name)} not found in AllTypesModule type_info"
    end
  end
end
