defmodule Nasaex.Result do
  @moduledoc """
  Convenience wrappers for ok/error tuples.
  """

  @spec ok(term()) :: {:ok, term()}
  def ok(value), do: {:ok, value}

  @spec error(term()) :: {:error, term()}
  def error(reason), do: {:error, reason}
end
