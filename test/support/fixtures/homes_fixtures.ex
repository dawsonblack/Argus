defmodule Argus.HomesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Argus.Homes` context.
  """

  @doc """
  Generate a home.
  """
  def home_fixture(attrs \\ %{}) do
    {:ok, home} =
      attrs
      |> Enum.into(%{
        address: "some address",
        name: "some name"
      })
      |> Argus.Homes.create_home()

    home
  end
end
