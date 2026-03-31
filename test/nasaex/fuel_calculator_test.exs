defmodule Nasaex.FuelCalculatorTest do
  use ExUnit.Case, async: true

  alias Nasaex.FuelCalculator

  describe "calculate/2 - example scenarios" do
    test "Apollo 11 mission: launch Earth, land Moon, launch Moon, land Earth" do
      path = [{:launch, "earth"}, {:land, "moon"}, {:launch, "moon"}, {:land, "earth"}]
      assert {:ok, 51_898} = FuelCalculator.calculate(28_801, path)
    end

    test "Mars mission: launch Earth, land Mars, launch Mars, land Earth" do
      path = [{:launch, "earth"}, {:land, "mars"}, {:launch, "mars"}, {:land, "earth"}]
      assert {:ok, 33_388} = FuelCalculator.calculate(14_606, path)
    end

    test "Passenger ship: Earth → Moon → Mars → Earth" do
      path = [
        {:launch, "earth"},
        {:land, "moon"},
        {:launch, "moon"},
        {:land, "mars"},
        {:launch, "mars"},
        {:land, "earth"}
      ]

      assert {:ok, 212_161} = FuelCalculator.calculate(75_432, path)
    end
  end

  describe "calculate/2 - single step" do
    test "landing on Earth with known fuel breakdown via calculate_step_fuel" do
      # From the spec: 28801 kg landing on Earth = 13447
      # 9278 + 2960 + 915 + 254 + 40 = 13447
      mass = Decimal.new(28_801)
      gravity = Decimal.new("9.807")
      assert 13_447 = FuelCalculator.calculate_step_fuel(mass, gravity, :land)
    end

    test "single launch from Moon" do
      path = [{:launch, "moon"}]
      assert {:ok, fuel} = FuelCalculator.calculate(1_000, path)
      assert fuel > 0
    end
  end

  describe "calculate/2 - input validation" do
    test "rejects zero mass" do
      assert {:error, _} = FuelCalculator.calculate(0, [{:launch, "earth"}])
    end

    test "rejects negative mass" do
      assert {:error, _} = FuelCalculator.calculate(-100, [{:launch, "earth"}])
    end

    test "rejects non-integer mass" do
      assert {:error, _} = FuelCalculator.calculate(1.5, [{:launch, "earth"}])
    end
  end

  describe "validate_path/1" do
    test "valid simple path" do
      path = [{:launch, "earth"}, {:land, "moon"}]
      assert :ok = FuelCalculator.validate_path(path)
    end

    test "valid single launch" do
      assert :ok = FuelCalculator.validate_path([{:launch, "earth"}])
    end

    test "rejects empty path" do
      assert {:error, _} = FuelCalculator.validate_path([])
    end

    test "valid path starting with land" do
      assert :ok = FuelCalculator.validate_path([{:land, "earth"}])
    end

    test "valid land then launch then land" do
      path = [{:land, "mars"}, {:launch, "mars"}, {:land, "earth"}]
      assert :ok = FuelCalculator.validate_path(path)
    end

    test "rejects consecutive launches" do
      path = [{:launch, "earth"}, {:launch, "moon"}]
      assert {:error, "Step 2: expected land, got launch"} = FuelCalculator.validate_path(path)
    end

    test "rejects launch from wrong planet after landing" do
      path = [{:launch, "earth"}, {:land, "moon"}, {:launch, "earth"}]

      assert {:error, msg} = FuelCalculator.validate_path(path)
      assert msg =~ "must launch from moon"
    end

    test "rejects unknown planet" do
      path = [{:launch, "jupiter"}]
      assert {:error, msg} = FuelCalculator.validate_path(path)
      assert msg =~ "Unknown celestial bodies"
    end
  end

  describe "calculate_step_fuel/3" do
    test "matches the spec example for landing on Earth" do
      # 28801 * 9.807 * 0.033 - 42 = 9278, then recursive adds 2960+915+254+40
      mass = Decimal.new(28_801)
      gravity = Decimal.new("9.807")
      assert 13_447 = FuelCalculator.calculate_step_fuel(mass, gravity, :land)
    end
  end
end
