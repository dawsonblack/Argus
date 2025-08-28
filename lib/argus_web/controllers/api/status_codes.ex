defmodule ArgusWeb.Api.StatusCodes do
  @moduledoc false

  @spec not_found(String.t(), Plug.Conn.t()) :: Plug.Conn.t()
  def not_found(thing, conn) do
    conn
    |> Plug.Conn.put_status(:not_found)
    |> Phoenix.Controller.json(%{
      error: %{code: 404, message: "#{thing} not found"}
    })
  end
end
