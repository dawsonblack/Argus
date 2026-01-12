# Script for populating the database. You can run it as:
#
#     mix run priv/repo/home_seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Argus.Repo.insert!(%Argus.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
alias Argus.Homes
alias Argus.Repo

Repo.query!("TRUNCATE TABLE homes, spaces, appliances, appliance_commands RESTART IDENTITY CASCADE")

Homes.create_home(%{name: "Beach House", address: "123 Guatamo Dr San Diego, CA, 91911"})
Homes.create_home(%{name: "Mountain Cabin", address: "5 Bison Circle Denver, CO, 80014"})
Homes.create_home(%{name: "Main Apartment", address: "20 Olentangy Meadows Dr Ste 315 Lewis Center, OH, 43035"})

home = Homes.get_home_by_slug("main-apartment")
Homes.create_space(home, %{name: "Bedroom"})
Homes.create_space(home, %{name: "Living Room"})
Homes.create_space(home, %{name: "Bathroom"})
Homes.create_space(home, %{name: "Office"})

space = Homes.get_space_by_slug(home, "bedroom")

#CHANGEME
#Homes.create_appliance(space, %{name: "Noise Maker", mac_address: "E0:E2:E6:6D:A8:CA"}) #windows
Homes.create_appliance(space, %{name: "Noise Maker", mac_address: "BA38DF23-BA87-3204-BF7C-F63DCFDBBB1F"}) #mac

appliance = Homes.get_appliance_by_slug(space, "noise-maker")

Homes.create_appliance_command(appliance,
      %{name: "handshake",
      command_type: "lifecycle",
      protocol: "bluetooth",
      uuid: "90759319-1668-44da-9ef3-492d593bd1e5",
      command: [["static", [0x06, 0xE0, 0xE2, 0xE6, 0x6D, 0xA8, 0xC8, 0xFF, 0xFF]]]})

Homes.create_appliance_command(appliance,
      %{name: "on",
      command_type: "write",
      protocol: "bluetooth",
      uuid: "90759319-1668-44da-9ef3-492d593bd1e5",
      command: [["static", [0x02, 0x01]]]})

Homes.create_appliance_command(appliance,
      %{name: "off",
      command_type: "write",
      protocol: "bluetooth",
      uuid: "90759319-1668-44da-9ef3-492d593bd1e5",
      command: [["static", [0x02, 0x00]]]})

Homes.create_appliance_command(appliance,
      %{name: "volume",
      command_type: "write",
      protocol: "bluetooth",
      uuid: "90759319-1668-44da-9ef3-492d593bd1e5",
      command: [["min", 100],
                ["max", 10],
                ["reverse", 0x01]]})

Homes.create_appliance_command(appliance,
      %{name: "power",
      command_type: "read",
      protocol: "bluetooth",
      uuid: "80c37f00-cc16-11e4-8830-0800200c9a66",
      command: [["charat", 3],
                ["int", 10],
                ["eq", 1],
                ["ifelse", "on", "off"]]})

Homes.create_appliance_command(appliance,
      %{name: "volume",
      command_type: "read",
      protocol: "bluetooth",
      uuid: "80c37f00-cc16-11e4-8830-0800200c9a66",
      command: [["substr", 0, 2],
                ["int", 16]]})



#80C37F00-CC16-11E4-8830-0800200C9A66
# for iex:

# alias Argus.Homes
# home = Homes.get_home_by_slug("main-apartment")
# space = Homes.get_space_by_slug(home, "bedroom")
# appliance = Homes.get_appliance_by_slug(space, "noise-maker")
# Argus.DeviceCommunication.CommandPipeline.send_command(appliance, "on")


# If you need to reset the database:

# mix ecto.drop
# mix ecto.create
# mix ecto.migrate
# MIX_ENV=test mix ecto.drop
# MIX_ENV=test mix ecto.create
# MIX_ENV=test mix ecto.migrate

# If you remake the database you need to comment out device supervisor in application.ex, otherwise seeds will crash
