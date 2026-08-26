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
Homes.create_space(home, %{name: "Kitchen"})
Homes.create_space(home, %{name: "Bathroom"})
Homes.create_space(home, %{name: "Office"})

bedroom = Homes.get_space_by_slug(home, "bedroom")
kitchen = Homes.get_space_by_slug(home, "kitchen")

#CHANGEME
Homes.create_appliance(bedroom, %{name: "Noise Maker", mac_address: "E0:E2:E6:6D:A8:CA", protocol: "bluetooth"}) #windows
#Homes.create_appliance(bedroom, %{name: "Noise Maker", mac_address: "BA38DF23-BA87-3204-BF7C-F63DCFDBBB1F", protocol: "bluetooth"}) #mac

Homes.create_appliance(kitchen, %{name: "Coffee Station Light", mac_address: "A4:C1:38:1E:8F:15:31:64", protocol: "zigbee"})

noise_maker = Homes.get_appliance_by_slug(bedroom, "noise-maker")
coffee_station_light = Homes.get_appliance_by_slug(kitchen, "coffee-station-light")

Homes.create_appliance_command(noise_maker,
      %{name: "handshake",
      command_type: "lifecycle",
      uuid: "90759319-1668-44da-9ef3-492d593bd1e5",
      command: [["static", [0x06, 0xE0, 0xE2, 0xE6, 0x6D, 0xA8, 0xC8, 0xFF, 0xFF]]]})

Homes.create_appliance_command(noise_maker,
      %{name: "on",
      command_type: "write",
      uuid: "90759319-1668-44da-9ef3-492d593bd1e5",
      command: [["static", [0x02, 0x01]]]})

Homes.create_appliance_command(noise_maker,
      %{name: "off",
      command_type: "write",
      uuid: "90759319-1668-44da-9ef3-492d593bd1e5",
      command: [["static", [0x02, 0x00]]]})

Homes.create_appliance_command(noise_maker,
      %{name: "volume",
      command_type: "write",
      uuid: "90759319-1668-44da-9ef3-492d593bd1e5",
      command: [["min", 100],
                ["max", 10],
                ["reverse", 0x01]]})

Homes.create_appliance_command(noise_maker,
      %{name: "on",
      command_type: "read",
      uuid: "80c37f00-cc16-11e4-8830-0800200c9a66",
      command: [["charat", 3],
                ["int", 10],
                ["eq", 1],
                ["ifelse", "on", "off"]]})

Homes.create_appliance_command(noise_maker,
      %{name: "off",
      command_type: "read",
      uuid: "80c37f00-cc16-11e4-8830-0800200c9a66",
      command: [["charat", 3],
                ["int", 10],
                ["eq", 1],
                ["ifelse", "on", "off"]]})

Homes.create_appliance_command(noise_maker,
      %{name: "power",
      command_type: "read",
      uuid: "80c37f00-cc16-11e4-8830-0800200c9a66",
      command: [["charat", 3],
                ["int", 10],
                ["eq", 1],
                ["ifelse", "on", "off"]]})

Homes.create_appliance_command(noise_maker,
      %{name: "volume",
      command_type: "read",
      uuid: "80c37f00-cc16-11e4-8830-0800200c9a66",
      command: [["substr", 0, 2],
                ["int", 16]]})



Homes.create_appliance_command(coffee_station_light,
      %{name: "on",
      command_type: "write",
      cluster: 6,
      endpoint: 1,
      command: [["static", 0x01]]})

Homes.create_appliance_command(coffee_station_light,
      %{name: "off",
      command_type: "write",
      cluster: 6,
      endpoint: 1,
      command: [["static", 0x00]]})

Homes.create_appliance_command(coffee_station_light,
      %{name: "toggle",
      command_type: "write",
      cluster: 6,
      endpoint: 1,
      command: [["static", 0x02]]})

Homes.create_appliance_command(coffee_station_light,
      %{name: "power",
      command_type: "read",
      cluster: 6,
      endpoint: 1,
      command: [["static", 0x0000]]})




#80C37F00-CC16-11E4-8830-0800200C9A66
# for iex:

# alias Argus.Homes
# home = Homes.get_home_by_slug("main-apartment")
# bedroom = Homes.get_space_by_slug(home, "bedroom")
# appliance = Homes.get_appliance_by_slug(bedroom, "noise-maker")
# Argus.DeviceCommunication.CommandPipeline.send_command(appliance, "on")


# If you need to reset the database THIS RESETS EVERYTHING ALL MESSAGES AND APPLIANCES AND HOMES:

# mix ecto.drop
# mix ecto.create
# mix ecto.migrate
# MIX_ENV=test mix ecto.drop
# MIX_ENV=test mix ecto.create
# MIX_ENV=test mix ecto.migrate

# to log into database do: psql -U postgres -d argus_dev

# If you remake the database you need to comment out device supervisor in application.ex, otherwise seeds will crash but this comment might can be deleted because I don't think that's a problem anymore
