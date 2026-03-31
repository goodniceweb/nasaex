defmodule Nasaex.Repo do
  use Ecto.Repo,
    otp_app: :nasaex,
    adapter: Ecto.Adapters.Postgres
end
