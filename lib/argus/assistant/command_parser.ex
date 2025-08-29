defmodule Assistant.CommandParser do
  alias Assistant.LLM

  def message_intent(message) do
    payload = %{
      "text" => message
    }
    headers = [{"Content-Type", "application/json"}]

    case HTTPoison.post("http://localhost:5050/model/parse", Jason.encode!(payload), headers) do #TODO: make the url and/or the port based on env vars
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
        LLM.llm_interpret_command(message, "main-apartment", "write")
        #TODO: Write should maybe not be hardcoded. When will you use lifecycle? Will you ever need to? What about read and write?
        #TODO: home slug should not be hardcoded
      "information" ->
        IO.puts("What do you wanna know? :)")
      "arithmetic" ->
        IO.puts("you doin maffs")
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
end
