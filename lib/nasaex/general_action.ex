defmodule Nasaex.GeneralAction do
  @moduledoc """
  Convenience wrappers for halt/cont tuples used in `Enum.reduce_while/3`.
  """

  @spec halt(term()) :: {:halt, term()}
  def halt(value), do: {:halt, value}

  @spec cont(term()) :: {:cont, term()}
  def cont(value), do: {:cont, value}
end
