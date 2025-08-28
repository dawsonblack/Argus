defmodule ArgusWeb.Api.HomeController do
  use ArgusWeb, :controller

  import ArgusWeb.Api.StatusCodes

  alias Argus.Homes
  alias Argus.Repo

  def show_homes(conn, _params) do
    homes = Homes.list_homes()
    IO.inspect(homes)
    json(conn, %{
      homes: Enum.map(homes, fn home ->
        %{
          id: home.id,
          name: home.name,
          address: home.address,
          slug: home.slug
        }
      end)
    })
  end

  def show_home(conn, %{"home_slug" => slug}) do
    case Homes.get_home_by_slug(slug) do
      nil ->
        not_found("Home", conn)

      home ->
        json(conn, %{
          id: home.id,
          name: home.name,
          address: home.address,
          slug: home.slug
        })
    end
  end

  def show_spaces(conn, %{"home_slug" => slug}) do
    case Homes.get_home_by_slug(slug) do
      nil ->
        not_found("Home", conn)

      home ->
        home = Repo.preload(home, :spaces)

        json(conn, %{
          spaces: Enum.map(home.spaces, fn s ->
            %{
              id: s.id,
              name: s.name,
              slug: s.slug,
              home_id: s.home_id
            }
          end)
        })
    end
  end

  def show_space(conn, %{"home_slug" => home_slug, "space_slug" => space_slug}) do
    case Homes.get_home_by_slug(home_slug) do
      nil ->
        not_found("Home", conn)

      home ->
        case Homes.get_space_by_slug(home, space_slug) do
          nil ->
            not_found("Space", conn)

          space ->
            json(conn, %{
              id: space.id,
              name: space.name,
              slug: space.slug,
              home_id: space.home_id
            })
        end
    end
  end

  def show_appliances(conn, %{"home_slug" => home_slug, "space_slug" => space_slug}) do
    case Homes.get_home_by_slug(home_slug) do
      nil ->
        not_found("Home", conn)

      home ->
        case Homes.get_space_by_slug(home, space_slug) do
          nil ->
            not_found("Space", conn)

          space ->
            space = Repo.preload(space, :appliances)

            json(conn, %{
              appliances: Enum.map(space.appliances, fn app ->
                %{
                  id: app.id,
                  name: app.name,
                  slug: app.slug,
                  space_id: app.space_id,
                  mac_address: app.mac_address
                }
              end)
            })
        end
    end
  end

  def show_appliance(conn, %{"home_slug" => home_slug, "space_slug" => space_slug, "appliance_slug" => appliance_slug}) do
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
                json(conn, %{
                  id: app.id,
                  name: app.name,
                  slug: app.slug,
                  space_id: app.space_id,
                  mac_address: app.mac_address
                })
            end
        end
    end
  end

  def show_appliance_commands(conn, %{"home_slug" => home_slug, "space_slug" => space_slug, "appliance_slug" => appliance_slug}) do
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
                app = Repo.preload(app, :appliance_commands)

                json(conn, %{
                  appliance_commands: Enum.map(app.appliance_commands, fn command ->
                    %{
                      id: command.id,
                      type: command.command_type,
                      name: command.name,
                      protocol: command.protocol,
                      appliance_id: command.appliance_id,
                      channel: command.channel,
                      command: command.command
                    }
                  end)
                })
            end
        end
    end
  end

#TODO: this is commented out for now because commands can share names
  # def show_appliance_command(conn, %{"home_slug" => home_slug, "space_slug" => space_slug,
  #                                                   "appliance_slug" => appliance_slug, "command_name" => command_name}) do

  #   case Homes.get_home_by_slug(home_slug) do
  #     nil ->
  #       not_found("Home", conn)

  #     home ->
  #       case Homes.get_space_by_slug(home, space_slug) do
  #         nil ->
  #           not_found("Space", conn)

  #         space ->
  #           case Homes.get_appliance_by_slug(space, appliance_slug) do
  #             nil ->
  #               not_found("Appliance", conn)

  #             app ->
  #               case Homes.get_appliance_command_by_name(app, command_name) do
  #                 nil ->
  #                   not_found("Appliance command", conn)

  #                 command ->
  #                   json(conn, %{
  #                     id: command.id,
  #                     name: command.name,
  #                     protocol: command.protocol,
  #                     appliance_id: command.appliance_id,
  #                     channel: command.channel,
  #                     command: command.command
  #                   })
  #               end
  #           end
  #       end
  #   end
  # end
end
