defmodule Nasaex.CelestialBodies do
  @moduledoc """
  Loads and provides access to the list of celestial bodies from a YAML file.
  Data is loaded at compile time and embedded in the module.
  """

  alias Nasaex.CelestialBody

  @celestial_bodies_path Path.join(:code.priv_dir(:nasaex), "data/celestial_bodies.yml")
  @external_resource @celestial_bodies_path

  @celestial_bodies @celestial_bodies_path
                    |> YamlElixir.read_from_file!()
                    |> Enum.map(&CelestialBody.from_map/1)

  @spec all() :: [CelestialBody.t()]
  def all, do: @celestial_bodies

  @spec get_by_slug(String.t()) :: CelestialBody.t() | nil
  def get_by_slug(slug) do
    Enum.find(@celestial_bodies, &(&1.slug == slug))
  end

  @spec get_by_slug!(String.t()) :: CelestialBody.t()
  def get_by_slug!(slug) do
    get_by_slug(slug) || raise "Unknown celestial body: #{slug}"
  end

  @spec slugs() :: [String.t()]
  def slugs, do: Enum.map(@celestial_bodies, & &1.slug)
end
