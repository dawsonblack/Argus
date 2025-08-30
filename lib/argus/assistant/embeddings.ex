defmodule Argus.Assistant.Embeddings do
  def embed(texts, model \\ "mxbai-embed-large")

  def embed(texts, model) when is_binary(texts), do: embed([texts], model)

  def embed(texts, model) when is_list(texts) do
    body = Jason.encode!(%{model: model, input: texts})

    case HTTPoison.post("http://localhost:11434/api/embed", body, [{"Content-Type", "application/json"}]) do #TODO: make the model an env var
      {:ok, %HTTPoison.Response{status_code: 200, body: resp_body}} ->
        case Jason.decode(resp_body) do
          {:ok, %{"embeddings" => embeddings}} ->
            if length(texts) != length(embeddings) do
              raise ArgumentError, "lists must be same length"
            end

            Enum.zip(texts, embeddings)
            |> Enum.map(fn {text, emb} -> %{"text" => text, "embedding" => emb} end)

          {:ok, decoded} ->
            {:error, {:unexpected_response, decoded}}

          {:error, decode_err} ->
            {:error, {:json_decode_failed, decode_err}}
        end

      {:ok, %HTTPoison.Response{status_code: code, body: resp_body}} ->
        {:error, {:http_error, code, resp_body}}

      {:error, err} ->
        {:error, {:request_failed, err}}
    end
  end

  defp unbatch([inner]) when is_list(inner), do: inner
  defp unbatch(vec), do: vec

  def cosine(u, v) do
    u = unbatch(u)
    v = unbatch(v)

    u = Enum.map(u, & &1 * 1.0)
    v = Enum.map(v, & &1 * 1.0)

    magnitude_u = :math.sqrt(Enum.reduce(u, 0.0, fn x, acc -> acc + x * x end))
    magnitude_v = :math.sqrt(Enum.reduce(v, 0.0, fn x, acc -> acc + x * x end))

    cond do
      magnitude_u == 0.0 or magnitude_v == 0.0 ->
        0.0

      true ->
        dot = Enum.zip(u, v) |> Enum.reduce(0.0, fn {a, b}, acc -> acc + a * b end)
        dot / (magnitude_u * magnitude_v)
    end
  end

  def get_closest_embeddings(ref_data, main_emb, max_results \\ 3, min_relevance \\ 0.60) do
    ref_data
    |> Enum.reduce([], fn item, acc ->
      emb = Map.get(item, "embedding") || Map.get(item, :embedding)
      text = Map.get(item, "text") || Map.get(item, :text)

      relevance = cosine(emb, main_emb)
      if relevance < min_relevance do
        acc
      else
        candidate = %{text: text, score: relevance}
        maybe_add_to_list(acc, candidate, max_results)
      end
    end)
  end

  defp maybe_add_to_list(acc, candidate, k) do
    acc1 = [candidate | acc]

    if length(acc1) <= k do
      acc1
    else
      weakest = Enum.min_by(acc1, & &1.score)
      List.delete(acc1, weakest)
    end
  end
end
