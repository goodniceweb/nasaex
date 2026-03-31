defmodule Nasaex.FuelCalculator do
  @moduledoc """
  Calculates fuel required for interplanetary missions.

  Fuel is calculated in reverse order because earlier steps must carry
  the fuel needed for all subsequent steps. Each step's fuel is computed
  recursively since fuel itself adds mass that requires more fuel.

  Formulas:
    - Launch: mass * gravity * 0.042 - 33 (rounded down)
    - Landing: mass * gravity * 0.033 - 42 (rounded down)
  """

  alias Nasaex.CelestialBodies
  alias Nasaex.GeneralAction
  alias Nasaex.Result

  @type action :: :launch | :land
  @type step :: {action(), String.t()}

  @launch_factor Decimal.new("0.042")
  @launch_offset Decimal.new("33")
  @land_factor Decimal.new("0.033")
  @land_offset Decimal.new("42")

  @no_fuel 0
  @consecutive_pair_size 2
  @sliding_window_step 1
  @first_pair_step_number 2

  @doc """
  Calculates total fuel for a mission given equipment mass and flight path.

  The path is a list of `{action, planet_slug}` tuples, e.g.:
  `[{:launch, "earth"}, {:land, "moon"}, {:launch, "moon"}, {:land, "earth"}]`

  Returns `{:ok, total_fuel}` or `{:error, reason}`.
  """
  @spec calculate(pos_integer(), [step()]) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def calculate(mass, path) when is_integer(mass) and mass > 0 and is_list(path) do
    with :ok <- validate_path(path) do
      total =
        path
        |> Enum.reverse()
        |> Enum.reduce(@no_fuel, fn {action, slug}, fuel_acc ->
          body = CelestialBodies.get_by_slug!(slug)
          step_mass = Decimal.new(mass + fuel_acc)
          step_fuel = calculate_step_fuel(step_mass, body.gravity, action)
          fuel_acc + step_fuel
        end)

      Result.ok(total)
    end
  end

  def calculate(_mass, _path), do: Result.error("Mass must be a positive integer")

  @doc """
  Recursively calculates fuel for a single step, accounting for the
  additional fuel weight until no more fuel is needed.
  """
  @spec calculate_step_fuel(Decimal.t(), Decimal.t(), action()) :: non_neg_integer()
  def calculate_step_fuel(mass, gravity, action) do
    do_calculate_step_fuel(mass, gravity, action, @no_fuel)
  end

  defp do_calculate_step_fuel(mass, gravity, action, acc) do
    fuel = compute_fuel(mass, gravity, action)

    if fuel <= @no_fuel do
      acc
    else
      do_calculate_step_fuel(Decimal.new(fuel), gravity, action, acc + fuel)
    end
  end

  defp compute_fuel(mass, gravity, :launch) do
    mass
    |> Decimal.mult(gravity)
    |> Decimal.mult(@launch_factor)
    |> Decimal.sub(@launch_offset)
    |> Decimal.to_float()
    |> floor()
  end

  defp compute_fuel(mass, gravity, :land) do
    mass
    |> Decimal.mult(gravity)
    |> Decimal.mult(@land_factor)
    |> Decimal.sub(@land_offset)
    |> Decimal.to_float()
    |> floor()
  end

  @doc """
  Validates that a flight path is logically consistent:
  - Must have at least one step
  - Must alternate launch/land (first step can be either)
  - After landing on planet X, must launch from planet X
  - All planet slugs must be known
  """
  @spec validate_path([step()]) :: :ok | {:error, String.t()}
  def validate_path([]), do: Result.error("Flight path must have at least one step")

  def validate_path(path) do
    known_slugs = CelestialBodies.slugs()

    with :ok <- validate_known_bodies(path, known_slugs),
         :ok <- validate_sequence(path) do
      :ok
    end
  end

  defp validate_known_bodies(path, known_slugs) do
    unknown =
      path
      |> Enum.map(fn {_action, slug} -> slug end)
      |> Enum.reject(&(&1 in known_slugs))
      |> Enum.uniq()

    case unknown do
      [] -> :ok
      slugs -> Result.error("Unknown celestial bodies: #{Enum.join(slugs, ", ")}")
    end
  end

  defp validate_sequence([_single_step]), do: :ok

  defp validate_sequence(path) do
    path
    |> Enum.chunk_every(@consecutive_pair_size, @sliding_window_step, :discard)
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {[{prev_action, prev_slug}, {action, slug}], pair_index},
                                  _acc ->
      step_num = pair_index + @first_pair_step_number

      cond do
        action == prev_action ->
          GeneralAction.halt(
            Result.error("Step #{step_num}: expected #{opposite(prev_action)}, got #{action}")
          )

        action == :launch && prev_slug != slug ->
          GeneralAction.halt(
            Result.error(
              "Step #{step_num}: must launch from #{prev_slug} (where you landed), not #{slug}"
            )
          )

        true ->
          GeneralAction.cont(:ok)
      end
    end)
  end

  defp opposite(:launch), do: :land
  defp opposite(:land), do: :launch
end
