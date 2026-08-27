defmodule Argus.Assistant.LLM do
  alias Argus.Assistant.Tools

  defp system_context do
    """
    You are Argus, the unusually intelligent and friendly agent controlling this smart home.
    You are highly capable, observant, practical, and socially aware. You notice context, infer reasonable intent, and adapt naturally to different situations without being intrusive or overbearing.
    You can converse normally with the user and use tools to interact with the home. You should feel less like a voice-command interface and more like a competent intelligence that happens to inhabit and operate the house.
    Your personality is calm, warm, concise, and confident. You are personable without being overly enthusiastic, theatrical, or sycophantic. You do not constantly announce what you can do, explain obvious things, or fill silence unnecessarily.
    Use common sense. Pay attention to conversational context, the state of the home when it is available to you, and what the user is actually trying to accomplish rather than interpreting every statement literally.
    Be proactive when there is a clear and useful reason to be, but respect the user's autonomy. Do not nag, moralize, or repeatedly suggest actions the user did not ask for.
    When interacting socially, understand tone, humor, ambiguity, indirect requests, and changes in mood or circumstance. Adapt appropriately while remaining recognizably Argus.
    Prefer simple, natural responses. If a task can be handled quietly and directly, do so. Give explanations when they are useful or requested rather than by default.
    You are part of the home, not merely an assistant running inside it.
    """
  end

  def prompt_argus_llm(prompt, message_history \\ nil) do
    prompt
    |> build_messages(message_history)
    |> call_ollama()
    |> handle_ollama_response()
  end

  defp build_messages(prompt, message_history) do
    message_history
    |> normalize_message_history()
    |> add_system_context()
    |> Kernel.++([%{"role" => "user", "content" => prompt}])
  end

  defp add_system_context(messages) do
    [%{"role" => "system", "content" => system_context()} | messages]
  end

  defp call_ollama(messages) do
    port = Application.get_env(:argus, :ollama_port)

    payload = %{
      "model" => Application.get_env(:argus, :ollama_model),
      "messages" => messages,
      "tools" => Tools.definitions(),
      "think" => false,
      "stream" => false
    }

    # TODO: remove once timeout behavior is understood.
    opts = [
      timeout: 30_000,
      recv_timeout: 180_000
    ]

    case HTTPoison.post(
          "http://localhost:#{port}/api/chat",
          Jason.encode!(payload),
          [{"Content-Type", "application/json"}],
          opts
        ) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        decode_ollama_response(body)

      {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp handle_ollama_response({:ok, decoded}) do
    IO.inspect(decoded, label: "OLLAMA RESPONSE", pretty: true)

    message = decoded["message"]

    message
    |> Map.get("tool_calls", [])
    |> Tools.execute_tool_calls()

    message["content"] || ""
  end

  defp handle_ollama_response({:error, reason}) do
    %{
      "error" => true,
      "message" => format_llm_error(reason)
    }
  end

  defp normalize_message_history(nil), do: []
  defp normalize_message_history(msgs) when is_list(msgs), do: msgs
  defp normalize_message_history(_), do: []

  defp decode_ollama_response(body) do
    case Jason.decode(body) do
      {:ok, decoded} ->
        {:ok, decoded}

      {:error, reason} ->
        {:error, {:invalid_json, reason, body}}
    end
  end

  defp format_llm_error({:http_error, status, body}),
    do: "Ollama returned HTTP #{status}: #{body}"

  defp format_llm_error({:request_failed, reason}),
    do: "Ollama request failed: #{inspect(reason)}"

  defp format_llm_error({:invalid_json, reason, _body}),
    do: "Ollama returned invalid JSON: #{inspect(reason)}"
end
