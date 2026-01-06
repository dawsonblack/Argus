defmodule Argus.Assistant.CommandParsing do
  import Argus.Assistant.CommandParser.ValidateCommandJson

  alias Argus.DeviceCommunication.CommandPipeline
  alias Argus.Assistant.LLM
  alias Argus.Homes

  def message_intent(message) do
    port = Application.get_env(:argus, :rasa_port)

    payload = %{
      "text" => message
    }
    headers = [{"Content-Type", "application/json"}]

    case HTTPoison.post("http://localhost:#{port}/model/parse", Jason.encode!(payload), headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        with {:ok, decoded} <- Jason.decode(body), content when is_binary(content) <- get_in(decoded, ["intent", "name"]) do
          content
        else
          _ -> %{"error" => :bad_response, "message" => body}
        end

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        %{"error" => code, "message" => body}

      {:error, err} ->
        %{"error" => :request_failed, "message" => inspect(err)}
    end
  end

  def parse_message(message) do
    case message_intent(message) do
      "action" ->
        IO.puts("action")
        #TODO: Write should maybe not be hardcoded (see the line below where it puts type into json as well). When will you use lifecycle? Will you ever need to? What about read and write?
        #TODO: home slug should not be hardcoded. Once it is not you will need to ensure it's a valid home slug
        LLM.llm_interpreted_command(message, "main-apartment", "write")
        |> String.replace("'", "\"")
        |> json_decode_or_nil()
        |> IO.inspect()
        |> maybe_put(
            "home",
            "main-apartment" |> Homes.get_home_by_slug()
          ) #TODO: this assumes the home slug given is always real

        |> maybe_put("type", "write")
        |> ensure_valid_json_structure()
        |> ensure_valid_space()
        |> IO.inspect()
        |> ensure_valid_appliance()
        |> IO.inspect()
        |> ensure_valid_command()
        #|> TODO: validate the user parameters and pass them in
        #CHANGEME just commenting this out for testing the above pipeline
        |> case do
          nil -> %{:error => %{:message => "Either the space, appliance, or command could not be determined"}}
          command_json ->
            appliance = command_json["device"]
            command_name = command_json["command"].name
            command_type = "write" #TODO: Possibly don't harcode this
            CommandPipeline.send_command(appliance, command_name, command_type)
        end


        #|> maybe get the params. Add them if you see them and return nil otherwise #TODO: you need to verify that the params are the proper object. Consider adding a regex into the commands stored in the database or something

      "information" ->
        IO.puts("read")
        LLM.llm_interpreted_command(message, "main-apartment", "read")

      "arithmetic" ->
        IO.puts("you doin maffs")
        system_context = "You are part of a calculator. Take a math question and format it into an arithmetic expression that can be evaluated.\n" <>
          "For example: \"what is nine plus ten\" -> \"9+10\"\n" <>
          "Return ONLY the expression, do not evaluate it and do not say anything else"
        LLM.prompt_llm(message, system_context)

      convo_or_other ->
        IO.puts(convo_or_other)
        system_context = "You are Argus, the home assistant for this household. You're in conversation mode.\n" <>
          "Style: brief, neutral, useful (1-3 sentences).\n" <>
          "Capabilities: do not claim to control devices in this mode." <>
          "If the user implies an action, or you sense that an action might be helpful in the context of your conversation with the user, " <>
          "suggest the action and ask if they would like you to perform it. Only do this if the conversation reveals that the given action might be relevant and useful to the user." <>
          "Otherwise, engage in conversation normally."
        LLM.prompt_llm(message, system_context)
      # other ->
      #   IO.puts()
      #   "Sorry, I couldn't make sense of what you said"
    end
  end

  #home is assumed to be known. A command will be accepted if
  # 1. space, device, and command are known
  # 2. space and device are known and device only has one command
  # 3. space and command are known and command is unique to space
  # 4. device and command are known and device is unique to home
end
