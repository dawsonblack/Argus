defmodule Argus.Assistant.CommandParsing do
  alias Argus.Assistant.LLM

  def message_intent(message) do
    port = 5050 #rasa port, this is gonna be delted soon

    payload = %{
      "prompt" => message,
      "model" => "intent"
    }
    headers = [{"Content-Type", "application/json"}]

    case HTTPoison.post("http://localhost:#{port}/predict", Jason.encode!(payload), headers) do
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

  def parse_message_was_the_function_this_used_to_call_but_now_im_testing_an_allinone_agent_model(message) do
    # convo_history = Argus.Chat.list_recent_messages(20)
    # |> Enum.drop(-1) # drop the last message, which is the user message that triggered this function
    # |> Enum.map(fn msg -> %{
    #   "role" =>
    #         if msg.sender == "assistant" do
    #           "assistant"
    #         else
    #           "user"
    #         end,

    #   "content" => msg.text} end)

    {
      :no_intent_just_direct_prompt,
      LLM.prompt_argus_llm(message)
    }
  end

  #home is assumed to be known. A command will be accepted if
  # 1. space, device, and command are known
  # 2. space and device are known and device only has one command
  # 3. space and command are known and command is unique to space
  # 4. device and command are known and device is unique to home
end
