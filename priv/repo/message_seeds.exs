# Script for populating the database. You can run it as:
#
#     mix run priv/repo/message_seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Argus.Repo.insert!(%Argus.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
alias Argus.Chat
alias Argus.Repo

#CHANGEME ---------!!!!!THE LINE BELOW WILL DELETE ALL OF YOUR CHAT HISTORY, BE CAREFUL WITH IT!!!!!---------
Repo.query!("TRUNCATE TABLE messages RESTART IDENTITY CASCADE")


Chat.create_message(%{
      sender: "Dawson",
      modality: "typed",
      text: "Hello Argus!"
})
Chat.create_message(%{
      sender: "assistant",
      modality: "typed",
      text: "Hello! How can I assist you in your home today?"
})
Chat.create_message(%{
      sender: "Dawson",
      modality: "typed",
      text: "I don't need anything now, I'm just filling in the database with dummy data"
})
Chat.create_message(%{
      sender: "Dawson",
      modality: "typed",
      text: "I need something to act as a decoy while I develop my chat UI"
})
Chat.create_message(%{
      sender: "assistant",
      modality: "typed",
      text: "Sounds good! Let me know if I can help with anything at all. I'll be sitting here in the cloud until then 😎"
})
Chat.create_message(%{
      sender: "Dawson",
      modality: "typed",
      text: "Argus you know you can't do that right? You're run entirely locally! In fact, that's one of the defining features of you and the smart home technology that you manage.\n\nI'm going to test a newline break now, let me know how it did"
})
Chat.create_message(%{
      sender: "assistant",
      modality: "typed",
      text: "I couldn't possibly know how it did becasue I'm not actually Argus speaking, but rather also Dawson in the seeds file, just hacking away at his keyboard at 12:30am to try and fill this database"
})

# If you need to reset the database:

# mix ecto.drop
# mix ecto.create
# mix ecto.migrate
# MIX_ENV=test mix ecto.drop
# MIX_ENV=test mix ecto.create
# MIX_ENV=test mix ecto.migrate

# If you remake the database you need to comment out device supervisor in application.ex, otherwise seeds will crash
