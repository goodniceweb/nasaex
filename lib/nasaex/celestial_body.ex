defmodule Nasaex.CelestialBody do
  @moduledoc """
  Struct representing a celestial body with its gravitational constant.
  """

  @enforce_keys [:name, :slug, :gravity]
  defstruct [:name, :slug, :gravity]

  @type t :: %__MODULE__{
          name: String.t(),
          slug: String.t(),
          gravity: Decimal.t()
        }

  @spec from_map(map()) :: t()
  def from_map(%{"name" => name, "slug" => slug, "gravity" => gravity}) do
    %__MODULE__{
      name: name,
      slug: slug,
      gravity: Decimal.new(to_string(gravity))
    }
  end
end
