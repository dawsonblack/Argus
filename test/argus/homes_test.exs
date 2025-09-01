defmodule Argus.HomesTest do
  use Argus.DataCase

  alias Argus.Homes

  describe "Home tests" do
    alias Argus.Homes.Home

    test "create a home with valid data" do
      attrs = %{name: "some name", address: "some address"}
      assert {:ok, %Home{} = home} = Homes.create_home(attrs)

      assert home.name == "some name"
      assert home.address == "some address"
      assert home.slug == "some-name"
    end


    test "create a home with missing column inputs" do
      attrs = %{name: "some name", address: nil}
      assert {:error, %Ecto.Changeset{}} = Homes.create_home(attrs)

      attrs = %{name: nil, address: "some address"}
      assert {:error, %Ecto.Changeset{}} = Homes.create_home(attrs)
    end


    test "does not allow duplicate slugs" do
      attrs = %{name: "some name", address: "some address"}
      attrs2 = %{name: "SOME_nAme", address: "some address"}

      {:ok, _home1} = Homes.create_home(attrs)
      {:error, changeset} = Homes.create_home(attrs2)

      assert %{slug: ["has already been taken"]} = errors_on(changeset)
    end

    # test "list_homes/0 returns all homes" do
    #   home = home_fixture()
    #   assert Homes.list_homes() == [home]
    # end

    # test "get_home!/1 returns the home with given id" do
    #   home = home_fixture()
    #   assert Homes.get_home!(home.id) == home
    # end

    # test "update_home/2 with valid data updates the home" do
    #   home = home_fixture()
    #   update_attrs = %{name: "some updated name", address: "some updated address"}

    #   assert {:ok, %Home{} = home} = Homes.update_home(home, update_attrs)
    #   assert home.name == "some updated name"
    #   assert home.address == "some updated address"
    # end

    # test "update_home/2 with invalid data returns error changeset" do
    #   home = home_fixture()
    #   assert {:error, %Ecto.Changeset{}} = Homes.update_home(home, @invalid_attrs)
    #   assert home == Homes.get_home!(home.id)
    # end

    # test "delete_home/1 deletes the home" do
    #   home = home_fixture()
    #   assert {:ok, %Home{}} = Homes.delete_home(home)
    #   assert_raise Ecto.NoResultsError, fn -> Homes.get_home!(home.id) end
    # end

    # test "change_home/1 returns a home changeset" do
    #   home = home_fixture()
    #   assert %Ecto.Changeset{} = Homes.change_home(home)
    # end

  end



  describe "Space tests" do
    alias Homes.Space

    test "create a sapce with valid data" do
      {:ok, home} = Homes.create_home(%{name: "some name", address: "some address"})

      attrs = %{name: "space name"}
      assert {:ok, %Space{} = space} = Homes.create_space(home, attrs)

      assert space.name == "space name"
      assert space.slug == "space-name"
      assert space.home_id == home.id
    end


    test "create a space with missing column inputs" do
      {:ok, home} = Homes.create_home(%{name: "some name", address: "some address"})

      attrs = %{name: nil}
      assert {:error, %Ecto.Changeset{}} = Homes.create_space(home, attrs)
    end


    test "does not allow duplicate slugs in same home" do
      {:ok, home} = Homes.create_home(%{name: "some name", address: "some address"})

      attrs = %{name: "space name"}
      attrs2 = %{name: "SPACE_nAme"}
      {:ok, _space1} = Homes.create_space(home, attrs)
      {:error, changeset} = Homes.create_space(home, attrs2)

      assert %{slug: ["has already been taken"]} = errors_on(changeset)
    end


    test "allows duplicate slugs for different homes" do
      {:ok, home1} = Homes.create_home(%{name: "home 1", address: "address 1"})
      {:ok, home2} = Homes.create_home(%{name: "home 2", address: "address 2"})

      attrs = %{name: "space name"}
      {:ok, _space1} = Homes.create_space(home1, attrs)
      {:ok, space2} = Homes.create_space(home2, attrs)

      assert space2.name == "space name"
      assert space2.slug == "space-name"
      assert space2.home_id == home2.id
    end
  end



  describe "Appliance tests" do
    alias Homes.Appliance

    test "create an appliance with valid data" do
      {:ok, home} = Homes.create_home(%{name: "home", address: "address"})
      {:ok, space} = Homes.create_space(home, %{name: "space"})

      attrs = %{name: "appliance name", mac_address: "mac"}

      assert {:ok, %Appliance{} = appliance} = Homes.create_appliance(home, attrs)
      assert appliance.name == "appliance name"
      assert appliance.mac_address == "mac"
      assert appliance.slug == "appliance-name"
      assert appliance.home_id == home.id
      assert appliance.space_id == nil

      assert {:ok, %Appliance{} = appliance} = Homes.create_appliance(space, attrs)
      assert appliance.name == "appliance name"
      assert appliance.mac_address == "mac"
      assert appliance.slug == "appliance-name"
      assert appliance.home_id == nil
      assert appliance.space_id == space.id
    end


    test "create an appliance with missing column inputs" do
      {:ok, home} = Homes.create_home(%{name: "home", address: "address"})
      {:ok, space} = Homes.create_space(home, %{name: "space"})

      attrs = %{name: "appliance name", mac_address: nil}
      assert {:error, %Ecto.Changeset{}} = Homes.create_appliance(space, attrs)

      attrs = %{name: nil, mac_address: "mac"}
      assert {:error, %Ecto.Changeset{}} = Homes.create_appliance(space, attrs)
    end


    test "does not allow duplicate slugs in same space or home" do
      {:ok, home} = Homes.create_home(%{name: "home", address: "address"})
      {:ok, space} = Homes.create_space(home, %{name: "space"})

      attrs = %{name: "appliance name", mac_address: "mac"}
      attrs2 = %{name: "APPLIANCE_NaMe", mac_address: "mac"}
      {:ok, _space} = Homes.create_appliance(home, attrs)
      {:ok, _space} = Homes.create_appliance(space, attrs)

      {:error, changeset1} = Homes.create_appliance(home, attrs2)
      {:error, changeset2} = Homes.create_appliance(space, attrs2)

      assert %{slug: ["has already been taken"]} = errors_on(changeset1)
      assert %{slug: ["has already been taken"]} = errors_on(changeset2)
    end


    test "allows duplicate slugs for different homes or spaces" do
      {:ok, home1} = Homes.create_home(%{name: "home 1", address: "address 1"})
      {:ok, home2} = Homes.create_home(%{name: "home 2", address: "address 2"})
      {:ok, space1} = Homes.create_space(home1, %{name: "space 1"})
      {:ok, space2} = Homes.create_space(home1, %{name: "space 2"})

      attrs = %{name: "appliance name", mac_address: "mac"}
      {:ok, _} = Homes.create_appliance(home1, attrs)
      {:ok, _} = Homes.create_appliance(space1, attrs)


      {:ok, appliance1} = Homes.create_appliance(home2, attrs)
      assert appliance1.name == "appliance name"
      assert appliance1.mac_address == "mac"
      assert appliance1.slug == "appliance-name"
      assert appliance1.home_id == home2.id
      assert appliance1.space_id == nil

      {:ok, appliance2} = Homes.create_appliance(space2, attrs)
      assert appliance2.name == "appliance name"
      assert appliance2.mac_address == "mac"
      assert appliance2.slug == "appliance-name"
      assert appliance2.home_id == nil
      assert appliance2.space_id == space2.id
    end
  end



  describe "Appliance Command tests" do
    alias Homes.ApplianceCommand

    test "create an appliance command with valid data" do
      {:ok, home} = Homes.create_home(%{name: "home", address: "address"})
      {:ok, appliance} = Homes.create_appliance(home, %{name: "appliance", mac_address: "mac"})

      attrs = %{name: "appliance command name", command_type: "lifecycle", command: ["static", [1]], channel: "channel", protocol: "bluetooth"}
      assert {:ok, %ApplianceCommand{} = appliance_command} = Homes.create_appliance_command(appliance, attrs)

      assert appliance_command.name == "appliance command name"
      assert appliance_command.command == Jason.encode!(["static", [1]])
      assert appliance_command.protocol == "bluetooth"
      assert appliance_command.appliance_id == appliance.id
    end


    test "create an appliance command with missing column inputs" do
      {:ok, home} = Homes.create_home(%{name: "home", address: "address"})
      {:ok, appliance} = Homes.create_appliance(home, %{name: "appliance", mac_address: "mac"})

      attrs = %{name: nil, command_type: "write", command: "a command", channel: "channel", protocol: "bluetooth"}
      assert {:error, %Ecto.Changeset{}} = Homes.create_appliance_command(appliance, attrs)

      attrs = %{name: "appliance command name", command_type: nil, command: "a command", channel: "channel", protocol: "bluetooth"}
      assert {:error, %Ecto.Changeset{}} = Homes.create_appliance_command(appliance, attrs)

      attrs = %{name: "appliance command name", command_type: "read", command: nil, channel: "channel", protocol: "bluetooth"}
      assert {:error, %Ecto.Changeset{}} = Homes.create_appliance_command(appliance, attrs)

      attrs = %{name: "appliance command name", command_type: "read", command: "a command", channel: "channel", protocol: nil}
      assert {:error, %Ecto.Changeset{}} = Homes.create_appliance_command(appliance, attrs)
    end
  end
end
