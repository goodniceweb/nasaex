defmodule NasaexWeb.MissionLive do
  use NasaexWeb, :live_view

  alias Nasaex.FuelCalculator
  alias Nasaex.CelestialBodies

  @initial_step_id 1
  @min_steps 1

  @default_steps [
    %{id: @initial_step_id, action: :launch, planet: "earth"}
  ]

  @example_scenarios [
    %{
      name: "Apollo 11 Mission",
      mass: 28_801,
      expected_fuel: 51_898,
      path: [
        {:launch, "earth"},
        {:land, "moon"},
        {:launch, "moon"},
        {:land, "earth"}
      ]
    },
    %{
      name: "Mars Mission",
      mass: 14_606,
      expected_fuel: 33_388,
      path: [
        {:launch, "earth"},
        {:land, "mars"},
        {:launch, "mars"},
        {:land, "earth"}
      ]
    },
    %{
      name: "Passenger Ship Mission",
      mass: 75_432,
      expected_fuel: 212_161,
      path: [
        {:launch, "earth"},
        {:land, "moon"},
        {:launch, "moon"},
        {:land, "mars"},
        {:launch, "mars"},
        {:land, "earth"}
      ]
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        mass: nil,
        mass_raw: "",
        mass_error: nil,
        steps: @default_steps,
        next_id: @initial_step_id + 1,
        result: nil,
        path_error: nil,
        min_steps: @min_steps,
        scenarios: @example_scenarios
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", params, socket) do
    mass_raw = params["mass"] || socket.assigns.mass_raw
    {mass, mass_error} = parse_mass(mass_raw)

    steps = update_steps_from_params(socket.assigns.steps, params)

    socket =
      socket
      |> assign(mass: mass, mass_raw: mass_raw, mass_error: mass_error, steps: steps)
      |> recalculate()

    {:noreply, socket}
  end

  def handle_event("add_step", _params, socket) do
    steps = socket.assigns.steps
    next_id = socket.assigns.next_id
    last_step = List.last(steps)

    new_step =
      case last_step do
        %{action: :launch, planet: planet} ->
          %{id: next_id, action: :land, planet: first_other_planet(planet)}

        %{action: :land, planet: planet} ->
          %{id: next_id, action: :launch, planet: planet}

        nil ->
          %{id: next_id, action: :launch, planet: "earth"}
      end

    socket =
      socket
      |> assign(steps: steps ++ [new_step], next_id: next_id + 1)
      |> recalculate()

    {:noreply, socket}
  end

  def handle_event("remove_step", _params, socket) do
    steps = socket.assigns.steps

    new_steps =
      if length(steps) > @min_steps do
        List.delete_at(steps, -1)
      else
        steps
      end

    socket =
      socket
      |> assign(steps: new_steps)
      |> recalculate()

    {:noreply, socket}
  end

  def handle_event("reset", _params, socket) do
    socket =
      socket
      |> assign(
        mass: nil,
        mass_raw: "",
        mass_error: nil,
        steps: @default_steps,
        next_id: @initial_step_id + 1,
        result: nil,
        path_error: nil
      )

    {:noreply, socket}
  end

  def handle_event("apply_scenario", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    scenario = Enum.at(@example_scenarios, index)

    steps =
      scenario.path
      |> Enum.with_index(@initial_step_id)
      |> Enum.map(fn {{action, planet}, id} ->
        %{id: id, action: action, planet: planet}
      end)

    next_id = length(steps) + @initial_step_id

    socket =
      socket
      |> assign(
        mass: scenario.mass,
        mass_raw: Integer.to_string(scenario.mass),
        mass_error: nil,
        steps: steps,
        next_id: next_id
      )
      |> recalculate()

    {:noreply, socket}
  end

  defp update_steps_from_params(steps, params) do
    steps
    |> Enum.with_index()
    |> Enum.map(fn {step, index} ->
      step =
        case params["action_#{index}"] do
          "launch" -> %{step | action: :launch}
          "land" -> %{step | action: :land}
          _ -> step
        end

      case params["planet_#{index}"] do
        nil -> step
        planet -> %{step | planet: planet}
      end
    end)
    |> recompute_subsequent_steps()
  end

  defp recompute_subsequent_steps([first | rest]) do
    {updated_rest, _acc} =
      Enum.map_reduce(rest, first, fn step, prev ->
        expected_action = if prev.action == :launch, do: :land, else: :launch

        step = %{step | action: expected_action}

        step =
          if step.action == :launch do
            %{step | planet: prev.planet}
          else
            step
          end

        {step, step}
      end)

    [first | updated_rest]
  end

  defp recompute_subsequent_steps(steps), do: steps

  defp parse_mass(""), do: {nil, nil}

  defp parse_mass(raw) do
    case Integer.parse(String.trim(raw)) do
      {n, ""} when n > 0 -> {n, nil}
      {n, ""} when n <= 0 -> {nil, "Mass must be a positive number"}
      _ -> {nil, "Mass must be a whole number"}
    end
  end

  defp recalculate(socket) do
    %{mass: mass, steps: steps} = socket.assigns

    if mass && mass > 0 do
      path = Enum.map(steps, fn %{action: action, planet: planet} -> {action, planet} end)

      case FuelCalculator.calculate(mass, path) do
        {:ok, fuel} ->
          assign(socket, result: fuel, path_error: nil)

        {:error, reason} ->
          assign(socket, result: nil, path_error: reason)
      end
    else
      assign(socket, result: nil, path_error: nil)
    end
  end

  defp first_other_planet(current_slug) do
    CelestialBodies.all()
    |> Enum.find(fn p -> p.slug != current_slug end)
    |> Map.get(:slug)
  end

  defp planet_options do
    Enum.map(CelestialBodies.all(), fn p -> {p.name, p.slug} end)
  end

  defp format_number(n) when is_integer(n) do
    n
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  defp action_label(:launch), do: "Launch"
  defp action_label(:land), do: "Land"

  defp body_name(slug), do: CelestialBodies.get_by_slug!(slug).name

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-8">
      <div class="flex flex-col lg:flex-row gap-8 max-w-5xl mx-auto">
        <%!-- Main Calculator --%>
        <div class="flex-1 min-w-0">
          <.header>
            NASA Fuel Calculator
            <:subtitle>
              Calculate the fuel required for interplanetary missions
            </:subtitle>
          </.header>

          <form phx-change="validate" class="space-y-6 mt-6">
            <%!-- Mass Input --%>
            <div class="card bg-base-200">
              <div class="card-body">
                <h2 class="card-title text-base">Spacecraft Mass</h2>
                <div class="form-control">
                  <label class="label">
                    <span class="label-text">Equipment mass (kg)</span>
                  </label>
                  <input
                    type="text"
                    inputmode="numeric"
                    placeholder="e.g. 28801"
                    value={@mass_raw}
                    name="mass"
                    class={[
                      "input input-bordered w-full",
                      @mass_error && "input-error"
                    ]}
                  />
                  <p :if={@mass_error} class="mt-1 text-sm text-error flex items-center gap-1">
                    <.icon name="hero-exclamation-circle" class="size-4" />
                    {@mass_error}
                  </p>
                </div>
              </div>
            </div>

            <%!-- Flight Path --%>
            <div class="card bg-base-200">
              <div class="card-body">
                <div class="flex items-center justify-between">
                  <h2 class="card-title text-base">Flight Path</h2>
                  <div class="flex gap-2">
                    <button
                      type="button"
                      phx-click="reset"
                      class="btn btn-sm btn-outline"
                    >
                      <.icon name="hero-arrow-path" class="size-4" /> Reset
                    </button>
                    <button
                      type="button"
                      phx-click="remove_step"
                      class="btn btn-sm btn-outline btn-error"
                      disabled={length(@steps) <= @min_steps}
                    >
                      <.icon name="hero-minus" class="size-4" /> Remove Step
                    </button>
                    <button
                      type="button"
                      phx-click="add_step"
                      class="btn btn-sm btn-outline btn-success"
                    >
                      <.icon name="hero-plus" class="size-4" /> Add Step
                    </button>
                  </div>
                </div>

                <div class="mt-4">
                  <ul class="steps steps-vertical w-full">
                    <li
                      :for={{step, index} <- Enum.with_index(@steps)}
                      class={[
                        "step",
                        step.action == :launch && "step-primary",
                        step.action == :land && "step-secondary"
                      ]}
                    >
                      <div class="flex items-center gap-3 py-2">
                        <%= if index == 0 do %>
                          <select
                            name={"action_#{index}"}
                            class="select select-sm select-bordered w-28"
                          >
                            <option value="launch" selected={step.action == :launch}>Launch</option>
                            <option value="land" selected={step.action == :land}>Land</option>
                          </select>
                        <% else %>
                          <span class={[
                            "badge badge-sm",
                            step.action == :launch && "badge-primary",
                            step.action == :land && "badge-secondary"
                          ]}>
                            {action_label(step.action)}
                          </span>
                        <% end %>

                        <%= if step.action == :launch && index > 0 do %>
                          <span class="font-medium">
                            {body_name(step.planet)}
                          </span>
                          <span class="text-xs text-base-content/50">(auto)</span>
                        <% else %>
                          <select
                            name={"planet_#{index}"}
                            class="select select-sm select-bordered"
                          >
                            <option
                              :for={{name, slug} <- planet_options()}
                              value={slug}
                              selected={slug == step.planet}
                            >
                              {name}
                            </option>
                          </select>
                        <% end %>
                      </div>
                    </li>
                  </ul>
                </div>
              </div>
            </div>

            <%!-- Results --%>
            <div class="card bg-base-200">
              <div class="card-body">
                <h2 class="card-title text-base">Fuel Required</h2>

                <div :if={@path_error} class="alert alert-error mt-2">
                  <.icon name="hero-exclamation-triangle" class="size-5" />
                  <span>{@path_error}</span>
                </div>

                <div :if={@result} class="mt-2">
                  <div class="stat">
                    <div class="stat-title">Total Fuel</div>
                    <div class="stat-value text-primary">{format_number(@result)} kg</div>
                  </div>
                </div>

                <div :if={!@result && !@path_error && !@mass_error} class="mt-2 text-base-content/50">
                  Enter spacecraft mass to see fuel requirements.
                </div>
              </div>
            </div>
          </form>
        </div>

        <%!-- Sidebar: Example Scenarios --%>
        <div class="lg:w-72 shrink-0">
          <h2 class="text-lg font-semibold mb-4">Example Missions</h2>
          <div class="space-y-4">
            <div :for={{scenario, index} <- Enum.with_index(@scenarios)} class="card bg-base-200">
              <div class="card-body p-4">
                <h3 class="card-title text-sm">{scenario.name}</h3>
                <div class="text-xs text-base-content/70 space-y-1 mt-1">
                  <p>
                    <span class="font-medium">Mass:</span> {format_number(scenario.mass)} kg
                  </p>
                  <div class="flex flex-wrap gap-1">
                    <span
                      :for={{action, slug} <- scenario.path}
                      class={[
                        "badge badge-xs",
                        action == :launch && "badge-primary",
                        action == :land && "badge-secondary"
                      ]}
                    >
                      {action_label(action)} {body_name(slug)}
                    </span>
                  </div>
                  <p>
                    <span class="font-medium">Expected Fuel:</span> {format_number(scenario.expected_fuel)} kg
                  </p>
                </div>
                <div class="card-actions mt-2">
                  <button
                    type="button"
                    phx-click="apply_scenario"
                    phx-value-index={index}
                    class="btn btn-xs btn-primary btn-soft w-full"
                  >
                    Apply
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
