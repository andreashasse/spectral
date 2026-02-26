defmodule Spectral.TypeInfoTest do
  use ExUnit.Case, async: true
  doctest Spectral.TypeInfo

  describe "new/0" do
    test "creates an empty type_info structure" do
      type_info = Spectral.TypeInfo.new()
      assert is_tuple(type_info)
      assert elem(type_info, 0) == :type_info
    end
  end

  describe "type operations" do
    setup do
      # Use Person module's actual type info for realistic testing
      person_type_info = Person.__spectra_type_info__()
      {:ok, person_type} = Spectral.TypeInfo.find_type(person_type_info, :t, 0)

      %{
        empty_type_info: Spectral.TypeInfo.new(),
        person_type_info: person_type_info,
        person_type: person_type
      }
    end

    test "add_type/4 adds a type to the type_info", %{
      empty_type_info: type_info,
      person_type: person_type
    } do
      updated = Spectral.TypeInfo.add_type(type_info, :my_type, 0, person_type)

      assert {:ok, ^person_type} = Spectral.TypeInfo.find_type(updated, :my_type, 0)
    end

    test "find_type/3 returns {:ok, type} when type exists", %{person_type_info: type_info} do
      assert {:ok, type} = Spectral.TypeInfo.find_type(type_info, :t, 0)
      assert is_tuple(type)
    end

    test "find_type/3 returns :error when type doesn't exist", %{empty_type_info: type_info} do
      assert :error = Spectral.TypeInfo.find_type(type_info, :nonexistent, 0)
    end

    test "get_type/3 returns type when it exists", %{person_type_info: type_info} do
      type = Spectral.TypeInfo.get_type(type_info, :t, 0)
      assert is_tuple(type)
    end

    test "get_type/3 raises when type doesn't exist", %{empty_type_info: type_info} do
      assert_raise ErlangError, fn ->
        Spectral.TypeInfo.get_type(type_info, :nonexistent, 0)
      end
    end

    test "add_type/4 overwrites existing type", %{
      empty_type_info: type_info,
      person_type: person_type
    } do
      # Add a type twice
      updated1 = Spectral.TypeInfo.add_type(type_info, :my_type, 0, person_type)
      updated2 = Spectral.TypeInfo.add_type(updated1, :my_type, 0, person_type)

      # Should still be able to find it
      assert {:ok, ^person_type} = Spectral.TypeInfo.find_type(updated2, :my_type, 0)
    end
  end

  describe "record operations" do
    setup do
      # Get a real record from Person module if it has any
      person_type_info = Person.__spectra_type_info__()

      %{
        empty_type_info: Spectral.TypeInfo.new(),
        person_type_info: person_type_info
      }
    end

    test "add_record/3 and find_record/2 work together", %{empty_type_info: type_info} do
      # Create a simple mock record (in real use this would be an sp_rec record)
      mock_record = {:sp_rec, :my_record, []}

      updated = Spectral.TypeInfo.add_record(type_info, :my_record, mock_record)

      assert {:ok, ^mock_record} = Spectral.TypeInfo.find_record(updated, :my_record)
    end

    test "find_record/2 returns :error when record doesn't exist", %{
      empty_type_info: type_info
    } do
      assert :error = Spectral.TypeInfo.find_record(type_info, :nonexistent)
    end

    test "get_record/2 returns record when it exists", %{empty_type_info: type_info} do
      mock_record = {:sp_rec, :my_record, []}
      updated = Spectral.TypeInfo.add_record(type_info, :my_record, mock_record)

      assert ^mock_record = Spectral.TypeInfo.get_record(updated, :my_record)
    end

    test "get_record/2 raises when record doesn't exist", %{empty_type_info: type_info} do
      assert_raise ErlangError, fn ->
        Spectral.TypeInfo.get_record(type_info, :nonexistent)
      end
    end
  end

  describe "function operations" do
    setup do
      %{empty_type_info: Spectral.TypeInfo.new()}
    end

    test "add_function/4 and find_function/3 work together", %{empty_type_info: type_info} do
      # Create a simple mock function spec
      mock_spec = [{:sp_function_spec, [], []}]

      updated = Spectral.TypeInfo.add_function(type_info, :my_func, 2, mock_spec)

      assert {:ok, ^mock_spec} = Spectral.TypeInfo.find_function(updated, :my_func, 2)
    end

    test "find_function/3 returns :error when function doesn't exist", %{
      empty_type_info: type_info
    } do
      assert :error = Spectral.TypeInfo.find_function(type_info, :nonexistent, 0)
    end

    test "function keys are distinct by arity", %{empty_type_info: type_info} do
      spec1 = [{:spec1}]
      spec2 = [{:spec2}]

      updated =
        type_info
        |> Spectral.TypeInfo.add_function(:my_func, 1, spec1)
        |> Spectral.TypeInfo.add_function(:my_func, 2, spec2)

      assert {:ok, ^spec1} = Spectral.TypeInfo.find_function(updated, :my_func, 1)
      assert {:ok, ^spec2} = Spectral.TypeInfo.find_function(updated, :my_func, 2)
    end
  end

  describe "integration with __spectra_type_info__/0" do
    test "can query Person module's type info" do
      type_info = Person.__spectra_type_info__()

      # Should have the :t type
      assert {:ok, person_type} = Spectral.TypeInfo.find_type(type_info, :t, 0)
      assert is_tuple(person_type)
    end

    test "can query Person.Address module's type info" do
      type_info = Person.Address.__spectra_type_info__()

      # Should have the :t type
      assert {:ok, address_type} = Spectral.TypeInfo.find_type(type_info, :t, 0)
      assert is_tuple(address_type)
    end

    test "can modify and re-add type from existing type_info" do
      type_info = Person.__spectra_type_info__()
      {:ok, person_type} = Spectral.TypeInfo.find_type(type_info, :t, 0)

      # Add it to a new type_info with a different name
      new_type_info =
        Spectral.TypeInfo.new()
        |> Spectral.TypeInfo.add_type(:custom_person, 0, person_type)

      assert {:ok, ^person_type} =
               Spectral.TypeInfo.find_type(new_type_info, :custom_person, 0)
    end
  end

  describe "type key distinction" do
    setup do
      person_type_info = Person.__spectra_type_info__()
      {:ok, person_type} = Spectral.TypeInfo.find_type(person_type_info, :t, 0)

      %{
        empty_type_info: Spectral.TypeInfo.new(),
        person_type: person_type
      }
    end

    test "types are distinct by name and arity", %{
      empty_type_info: type_info,
      person_type: person_type
    } do
      mock_type = {:sp_simple_type, :integer, %{}}

      updated =
        type_info
        |> Spectral.TypeInfo.add_type(:my_type, 0, person_type)
        |> Spectral.TypeInfo.add_type(:my_type, 1, mock_type)

      assert {:ok, ^person_type} = Spectral.TypeInfo.find_type(updated, :my_type, 0)
      assert {:ok, ^mock_type} = Spectral.TypeInfo.find_type(updated, :my_type, 1)
    end
  end
end
