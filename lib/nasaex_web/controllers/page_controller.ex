defmodule NasaexWeb.PageController do
  use NasaexWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
