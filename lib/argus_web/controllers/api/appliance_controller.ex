defmodule ArgusWeb.Api.ApplianceController do
  use ArgusWeb, :controller

  import ArgusWeb.Api.StatusCodes

  alias Argus.Homes
  alias Argus.CommandPipeline

  def read_from_device(conn, %{"home_slug" => home_slug, "space_slug" => space_slug,
                                                    "appliance_slug" => appliance_slug, "command_name" => command_name}) do

    case Homes.get_home_by_slug(home_slug) do
      nil ->
        not_found("Home", conn)

      home ->
        case Homes.get_space_by_slug(home, space_slug) do
          nil ->
            not_found("Space", conn)

          space ->
            case Homes.get_appliance_by_slug(space, appliance_slug) do
              nil ->
                not_found("Appliance", conn)

              app ->
                case Homes.get_appliance_command_by_name_and_type(app, command_name, "read") do
                  nil ->
                    not_found("Appliance command", conn)

                  _ ->
                    conn
                    |> Plug.Conn.put_status(:not_implemented)
                    |> Phoenix.Controller.json(%{
                      error: %{code: 501, message: "Coming soon!"}
                    })
                end
            end
        end
    end
  end

  def write_to_device(conn, %{"home_slug" => home_slug, "space_slug" => space_slug, "appliance_slug" => appliance_slug,
                                              "command_name" => command_name, "params" => user_params}) do

    case Homes.get_home_by_slug(home_slug) do
      nil ->
        not_found("Home", conn)

      home ->
        case Homes.get_space_by_slug(home, space_slug) do
          nil ->
            not_found("Space", conn)

          space ->
            case Homes.get_appliance_by_slug(space, appliance_slug) do
              nil ->
                not_found("Appliance", conn)

              app ->
                case Homes.get_appliance_command_by_name_and_type(app, command_name, "write") do
                  nil ->
                    not_found("Appliance command", conn)

                  _command ->

                    user_input =
                      case user_params do
                        [first | _rest] -> first #TODO: this assumes just one user input at max
                        _ -> nil
                      end

                    CommandPipeline.send_command(app, command_name, "write", user_input) #TODO: this isn't finished yet

                    conn
                    |> Plug.Conn.put_status(:accepted)
                    |> Phoenix.Controller.json(%{code: 202, message: "The command has been sent. Currently we have no way to verify if it worked :("})
                end
            end
        end
    end
  end
end
