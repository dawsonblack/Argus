defmodule Argus.Assistant.LLM do
  import Argus.Assistant.Embeddings
  alias Argus.Assistant.DeviceCapabilities

  def prompt_llm(prompt, system_context \\ nil, message_history \\ nil) do
    model = Application.get_env(:argus, :ollama_model)
    port = Application.get_env(:argus, :ollama_port)

    Application.get_env(:argus, :ollama_model)

    messages =
      (case message_history do
         nil -> []
         msgs when is_list(msgs) -> msgs
         _ -> []
       end)
      |> maybe_prepend_system(system_context)
      |> Kernel.++([%{"role" => "user", "content" => prompt}])

    payload = %{
      "model" => model,
      "messages" => messages,
      "stream" => false
    }

    headers = [{"Content-Type", "application/json"}]

    #TODO delete these opts, they are a bandaid for timeout errors
    opts = [timeout: 30_000, recv_timeout: 180_000]
    case HTTPoison.post("http://localhost:#{port}/api/chat", Jason.encode!(payload), headers, opts) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        with {:ok, decoded} <- Jason.decode(body),
             content when is_binary(content) <- get_in(decoded, ["message", "content"]) do
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

  defp maybe_prepend_system(messages, nil), do: messages
  defp maybe_prepend_system(messages, ""), do: messages

  defp maybe_prepend_system(messages, system_context) when is_binary(system_context) do
    [%{"role" => "system", "content" => system_context} | messages]
  end


  defp command_with_rag(sentences, prompt) do
    rag_prompt = "#{prompt}\n---- END USER TEXT ----\n\n"

    rag_prompt =
      if Enum.any?(sentences) do
        rag_prompt <>
          "CONTEXT (authoritative facts; use only these):\n" <>
          Enum.map_join(sentences, "", fn s ->
            "#{Map.get(s, :text) || Map.get(s, "text") || to_string(s)}\n"
          end) <>
          "---- END FACTS ----\n\n"
      else
        rag_prompt
      end

      rag_prompt <>
        "Examples of correct output:\n" <>
        "{\"room\":\"bedroom\",\"device\":\"fan\",\"command\":\"speed\",\"params\":[31]}\n" <>
        "{\"room\":\"office\",\"device\":\"lamp\",\"command\":\"brightness\",\"params\":[\"-10\"]}\n" <>
        "{\"room\":\"bedroom\",\"device\":\"light\",\"command\":\"on\",\"params\":[]}\n" <>
        "{\"room\":null,\"device\":\"noise_maker\",\"command\":\"volume\",\"params\":[50]}\n\n" <>

        "Never do this (invalid):\n" <>
        "- {\"room\":\"bedroom\"} Here's the JSON you asked for...\n" <>
        "- ```json {...} ```\n" <>
        "- {\"room\":\"bedroom\",\"device\":\"noise_maker\",\"command\":\"volume\",\"params\":[,]}"
    #rag_prompt
  end

  def llm_interpreted_command(prompt, home_slug, command_type, max_rag_context \\ 3, min_rag_relevance \\ 0.60,
              msg_history \\ nil) do

    system_message = "You are Argus's smart-home command parser.\n" <>
      "Return ONLY valid JSON in this exact schema (no extra text, no code fences):\n{\n" <>
      "\"room\": string|null,          // e.g., \"bedroom\"\n" <>
      "\"device\": string|null,        // e.g., \"light\"\n" <>
      "\"command\": string|null,       // e.g., \"on\"\n" <>
      "\"params\": array|null          // [] if none; numbers are numeric; relative change as strings \"+N\" or \"-N\"\n}\n" <>
      "Rules:\n- Use ONLY devices/rooms/commands mentioned in the facts.\n" <>
      "- If any field is missing or ambiguous, set it to null instead of guessing.\n" <>
      "- If user requests a relative change, encode as \"+N\" or \"-N\" (strings). Absolute values are numbers.\n" <>
      "- Do not add fields. Do not include comments. Do not wrap in code fences.\n" <>
      "- Output must be a single JSON object and must parse with a strict JSON parser."

    embedded_prompt =
      prompt
      |> embed()
      |> List.first()
      |> Map.get("embedding")

    home_slug
    |> DeviceCapabilities.load_capability_embeddings(command_type)
    |> get_closest_embeddings(embedded_prompt, max_rag_context, min_rag_relevance)
    |> command_with_rag(prompt)
    |> prompt_llm(system_message, msg_history)
  end
end
