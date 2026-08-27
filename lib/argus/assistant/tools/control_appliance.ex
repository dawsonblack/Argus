defmodule Argus.Assistant.Tools.ControlAppliance do
  @moduledoc """
  Executes assistant tools against trusted Argus data.

  The language model is treated only as an interpreter of user intent. Appliance
  identities, spaces, commands, and values are verified against the database
  before any device command is sent.
  """

  alias Argus.Assistant.Embeddings
  alias Argus.DeviceCommunication.CommandPipeline
  alias Argus.Homes
  alias Argus.Homes.Appliance
  alias Argus.Homes.ApplianceCommand
  alias Argus.Repo

  @appliance_min_similarity 0.60
  @space_min_similarity 0.60
  @command_min_similarity 0.55

  # Keep candidates that are close enough to the best semantic match. This lets
  # later evidence (space and command capability) resolve genuine ambiguity.
  @appliance_similarity_window 0.08
  @space_similarity_window 0.08
  @command_similarity_window 0.08

  @doc """
  Resolves and executes a `control_appliance` tool call.

  Returns a JSON-friendly success or error map. Resolution stops immediately on
  the first error; it never guesses past failed validation.
  """
  def control_appliance(arguments, home_slug \\ "house")
  def control_appliance(arguments, home_slug) when is_map(arguments) do
    with {:ok, request} <- normalize_request(arguments),
         {:ok, home} <- get_home(home_slug),
         {:ok, appliances} <- load_home_appliances(home),
         {:ok, appliance_candidates} <- find_appliance_candidates(appliances, request.query),
         {:ok, appliance_candidates} <- disambiguate_by_space(appliance_candidates, home, request.space),
         {:ok, appliance, command} <- resolve_write_command(appliance_candidates, request.action, request.property),
         {:ok, value} <- validate_value(command, request.value),
         {:ok, payload} <- build_payload(appliance, command, value),
         :ok <- CommandPipeline.send_command_to_device(payload) do
      %{
        "ok" => true,
        "appliance_id" => appliance.id,
        "appliance" => appliance.name,
        "command" => command.name,
        "value" => value
      }
    else
      {:error, reason} ->
        %{
          "ok" => false,
          "error" => format_error(reason)
        }
    end
  end

  def control_appliance(_arguments, _home_slug) do
    %{
      "ok" => false,
      "error" => "Tool arguments must be an object."
    }
  end

  # Request normalization

  defp normalize_request(arguments) do
    request = %{
      query: clean_string(arguments["query"]),
      space: clean_nullable_string(arguments["space"]),
      action: clean_string(arguments["action"]),
      property: clean_nullable_string(arguments["property"]),
      value: normalize_value(arguments["value"])
    }

    cond do
      is_nil(request.query) ->
        {:error, :missing_query}

      is_nil(request.action) ->
        {:error, :missing_action}

      true ->
        {:ok, request}
    end
  end

  defp clean_string(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp clean_string(_value), do: nil

  defp clean_nullable_string(nil), do: nil
  defp clean_nullable_string(value), do: clean_string(value)

  defp normalize_value(nil), do: nil
  defp normalize_value(value) when is_number(value), do: value

  defp normalize_value(value) when is_binary(value) do
    value = String.trim(value)

    case Integer.parse(value) do
      {integer, ""} ->
        integer

      _ ->
        case Float.parse(value) do
          {float, ""} -> float
          _ -> value
        end
    end
  end

  defp normalize_value(value), do: value

  # Trusted home/appliance data

  defp get_home(home_slug) do
    case Homes.get_home_by_slug(home_slug) do
      nil -> {:error, {:home_not_found, home_slug}}
      home -> {:ok, home}
    end
  end

  defp load_home_appliances(home) do
    appliances =
      Homes.list_appliances()
      |> Repo.preload([:space, :appliance_commands])
      |> Enum.filter(&belongs_to_home?(&1, home.id))

    case appliances do
      [] -> {:error, :no_appliances}
      _ -> {:ok, appliances}
    end
  end

  defp belongs_to_home?(%Appliance{home_id: home_id}, home_id) when not is_nil(home_id),
    do: true

  defp belongs_to_home?(%Appliance{space: %{home_id: home_id}}, home_id),
    do: true

  defp belongs_to_home?(_appliance, _home_id),
    do: false

  # Appliance resolution

  defp find_appliance_candidates(appliances, query) do
    with {:ok, ranked} <- rank_semantically(appliances, query, &appliance_search_text/1) do
      case keep_plausible_matches(
             ranked,
             @appliance_min_similarity,
             @appliance_similarity_window
           ) do
        [] -> {:error, {:appliance_not_found, query}}
        candidates -> {:ok, candidates}
      end
    end
  end

  defp appliance_search_text(appliance) do
    [appliance.name, appliance.slug]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  # Space is only used when appliance identity is still ambiguous.
  #
  # A home-level appliance remains eligible regardless of the supplied space.
  # That prevents an LLM-inferred room from excluding whole-home appliances
  # such as HVAC.
  defp disambiguate_by_space([candidate], _home, _space),
    do: {:ok, [candidate]}

  defp disambiguate_by_space(candidates, _home, nil),
    do: {:ok, candidates}

  defp disambiguate_by_space(candidates, home, requested_space) do
    candidate_spaces =
      candidates
      |> Enum.map(& &1.item.space)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq_by(& &1.id)

    with {:ok, matched_spaces} <- find_space_matches(candidate_spaces, home, requested_space) do
      matched_space_ids =
        matched_spaces
        |> Enum.map(& &1.id)
        |> MapSet.new()

      narrowed =
        Enum.filter(candidates, fn %{item: appliance} ->
          is_nil(appliance.space) or MapSet.member?(matched_space_ids, appliance.space.id)
        end)

      case narrowed do
        [] -> {:error, {:space_excludes_all_candidates, requested_space}}
        _ -> {:ok, narrowed}
      end
    end
  end

  defp find_space_matches([], _home, requested_space),
    do: {:error, {:space_not_found, requested_space}}

  defp find_space_matches(candidate_spaces, home, requested_space) do
    # First prefer spaces already represented by candidate appliances. If the
    # supplied space is hallucinated, it cannot create a new appliance match.
    with {:ok, ranked} <-
           rank_semantically(candidate_spaces, requested_space, &space_search_text/1) do
      matches =
        keep_plausible_matches(
          ranked,
          @space_min_similarity,
          @space_similarity_window
        )

      case matches do
        [] ->
          # Distinguish "real space, irrelevant here" from "space does not exist."
          case real_space_match?(home, requested_space) do
            {:ok, true} ->
              {:error, {:space_does_not_match_candidates, requested_space}}

            {:ok, false} ->
              {:error, {:space_not_found, requested_space}}

            {:error, reason} ->
              {:error, reason}
          end

        matches ->
          {:ok, Enum.map(matches, & &1.item)}
      end
    end
  end

  defp space_search_text(space) do
    [space.name, space.slug]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  # Command resolution

  defp resolve_write_command(appliance_candidates, action, property) do
    command_candidates =
      appliance_candidates
      |> Enum.flat_map(fn %{item: appliance, score: appliance_score} ->
        appliance.appliance_commands
        |> Enum.filter(&(&1.command_type == "write"))
        |> Enum.map(fn command ->
          %{
            appliance: appliance,
            appliance_score: appliance_score,
            command: command
          }
        end)
      end)

    if command_candidates == [] do
      {:error, :no_write_commands}
    else
      command_query = command_query(action, property)

      with {:ok, ranked} <-
             rank_semantically(command_candidates, command_query, fn candidate ->
               command_search_text(candidate.command)
             end) do
        ranked
        |> keep_plausible_matches(@command_min_similarity, @command_similarity_window)
        |> resolve_command_match(command_query)
      end
    end
  end

  defp command_query(action, property) do
    [humanize(action), property]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  defp command_search_text(%ApplianceCommand{name: name}) do
    normalized = humanize(name)

    aliases =
      case String.downcase(normalized) do
        "on" -> "turn on power enable activate"
        "off" -> "turn off power disable deactivate"
        "toggle" -> "toggle switch power"
        other -> other
      end

    "#{normalized} #{aliases}"
  end

  defp resolve_command_match([], command_query),
    do: {:error, {:command_not_found, command_query}}

  defp resolve_command_match(
         [%{item: %{appliance: appliance, command: command}}],
         _command_query
       ) do
    {:ok, appliance, command}
  end

  defp resolve_command_match(matches, _command_query) do
    # The semantic command result includes appliance identity. If several
    # candidates survive within the confidence window, there is no unique,
    # verified target and we deliberately stop.
    unique_pairs =
      matches
      |> Enum.map(fn %{item: %{appliance: appliance, command: command}} ->
        {appliance.id, command.id}
      end)
      |> Enum.uniq()

    case unique_pairs do
      [{appliance_id, command_id}] ->
        %{item: %{appliance: appliance, command: command}} =
          Enum.find(matches, fn %{item: %{appliance: appliance, command: command}} ->
            appliance.id == appliance_id and command.id == command_id
          end)

        {:ok, appliance, command}

      _ ->
        {:error, :ambiguous_appliance_command}
    end
  end

  # Value validation

  defp validate_value(command, value) do
    with {:ok, pipeline} <- decode_command_pipeline(command),
         {:ok, value} <- validate_value_presence(pipeline, value),
         :ok <- validate_numeric_bounds(pipeline, value) do
      {:ok, value}
    end
  end

  defp decode_command_pipeline(%ApplianceCommand{command: command}) do
    case Jason.decode(command) do
      {:ok, pipeline} when is_list(pipeline) -> {:ok, pipeline}
      {:ok, _other} -> {:error, :invalid_command_pipeline}
      {:error, reason} -> {:error, {:invalid_command_pipeline, reason}}
    end
  end

  defp validate_value_presence(pipeline, value) do
    if static_pipeline?(pipeline) do
      if is_nil(value) do
        {:ok, nil}
      else
        {:error, :value_provided_for_static_command}
      end
    else
      if is_nil(value) do
        {:error, :value_required}
      else
        {:ok, value}
      end
    end
  end

  defp static_pipeline?([["static" | _] | _]), do: true
  defp static_pipeline?(_pipeline), do: false

  # The current command-pipeline convention uses:
  #   ["max", n] as a lower clamp
  #   ["min", n] as an upper clamp
  #
  # Validate those bounds before execution so invalid values fail instead of
  # being silently clamped.
  defp validate_numeric_bounds(_pipeline, value) when not is_number(value),
    do: :ok

  defp validate_numeric_bounds(pipeline, value) do
    lower_bound =
      pipeline
      |> bound_values("max")
      |> Enum.max(fn -> nil end)

    upper_bound =
      pipeline
      |> bound_values("min")
      |> Enum.min(fn -> nil end)

    cond do
      not is_nil(lower_bound) and value < lower_bound ->
        {:error, {:value_below_minimum, value, lower_bound}}

      not is_nil(upper_bound) and value > upper_bound ->
        {:error, {:value_above_maximum, value, upper_bound}}

      true ->
        :ok
    end
  end

  defp bound_values(pipeline, operation) do
    pipeline
    |> Enum.flat_map(fn
      [^operation, bound] when is_number(bound) -> [bound]
      _ -> []
    end)
  end

  # Payload construction doubles as the final compatibility check. If a value
  # has the wrong type for a command pipeline, the pipeline raises and the tool
  # fails without sending anything.
  defp build_payload(appliance, command, value) do
    try do
      {:ok, CommandPipeline.write_payload(appliance, command.name, "write", value)}
    rescue
      error ->
        {:error, {:command_value_rejected, Exception.message(error)}}
    catch
      kind, reason ->
        {:error, {:command_value_rejected, "#{kind}: #{inspect(reason)}"}}
    end
  end

  # Semantic ranking

  defp rank_semantically(items, query, text_fun) do
    texts = Enum.map(items, text_fun)

    with {:ok, query_embedding} <- embed_one(query),
         {:ok, embeddings} <- embed_many(texts) do
      ranked =
        items
        |> Enum.zip(embeddings)
        |> Enum.map(fn {item, embedding} ->
          %{
            item: item,
            score: Embeddings.cosine(embedding, query_embedding)
          }
        end)
        |> Enum.sort_by(& &1.score, :desc)

      {:ok, ranked}
    end
  end

  defp real_space_match?(home, query) do
    spaces = Homes.list_spaces_in_home(home)

    if spaces == [] do
      {:ok, false}
    else
      with {:ok, ranked} <- rank_semantically(spaces, query, &space_search_text/1) do
        {:ok, Enum.any?(ranked, &(&1.score >= @space_min_similarity))}
      end
    end
  end

  defp embed_one(text) do
    case Embeddings.embed(text) do
      [%{"embedding" => embedding}] -> {:ok, embedding}
      {:error, reason} -> {:error, reason}
      other -> {:error, {:unexpected_embedding_response, other}}
    end
  end

  defp embed_many([]), do: {:ok, []}

  defp embed_many(texts) do
    case Embeddings.embed(texts) do
      results when is_list(results) ->
        embeddings =
          Enum.map(results, fn
            %{"embedding" => embedding} -> embedding
            %{embedding: embedding} -> embedding
          end)

        if length(embeddings) == length(texts) do
          {:ok, embeddings}
        else
          {:error, :embedding_count_mismatch}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp keep_plausible_matches([], _minimum_similarity, _window),
    do: []

  defp keep_plausible_matches(ranked, minimum_similarity, window) do
    best_score = ranked |> hd() |> Map.fetch!(:score)
    cutoff = max(minimum_similarity, best_score - window)

    Enum.filter(ranked, &(&1.score >= cutoff))
  end

  defp humanize(nil), do: nil

  defp humanize(value) do
    value
    |> to_string()
    |> String.replace(["_", "-"], " ")
    |> String.trim()
  end

  # Errors are intentionally concise because these become tool results supplied
  # back to the language model.
  defp format_error(:missing_query), do: "No appliance query was provided."
  defp format_error(:missing_action), do: "No appliance action was provided."
  defp format_error(:no_appliances), do: "This home has no appliances."
  defp format_error(:no_write_commands), do: "No matching appliance has write commands."
  defp format_error(:ambiguous_appliance_command), do: "The appliance command is ambiguous."
  defp format_error(:embedding_count_mismatch), do: "Embedding results did not match the requested inputs."
  defp format_error(:value_required), do: "The selected command requires a value."

  defp format_error(:value_provided_for_static_command),
    do: "The selected command does not accept a value."

  defp format_error(:invalid_command_pipeline),
    do: "The selected command has an invalid command pipeline."

  defp format_error({:home_not_found, slug}),
    do: "Home #{inspect(slug)} was not found."

  defp format_error({:appliance_not_found, query}),
    do: "No appliance matched #{inspect(query)}."

  defp format_error({:space_not_found, space}),
    do: "No real space matched #{inspect(space)}."

  defp format_error({:space_does_not_match_candidates, space}),
    do: "Space #{inspect(space)} does not contain any matching appliance."

  defp format_error({:space_excludes_all_candidates, space}),
    do: "Space #{inspect(space)} excluded every appliance candidate."

  defp format_error({:command_not_found, query}),
    do: "No write command matched #{inspect(query)}."

  defp format_error({:value_below_minimum, value, minimum}),
    do: "Value #{inspect(value)} is below the command minimum of #{inspect(minimum)}."

  defp format_error({:value_above_maximum, value, maximum}),
    do: "Value #{inspect(value)} is above the command maximum of #{inspect(maximum)}."

  defp format_error({:invalid_command_pipeline, _reason}),
    do: "The selected command has an invalid command pipeline."

  defp format_error({:command_value_rejected, reason}),
    do: "The selected command rejected the supplied value: #{reason}"

  defp format_error({:unexpected_embedding_response, _response}),
    do: "The embedding service returned an unexpected response."

  defp format_error({:unexpected_response, _response}),
    do: "The embedding service returned an unexpected response."

  defp format_error({:json_decode_failed, _reason}),
    do: "The embedding service returned invalid JSON."

  defp format_error({:http_error, status, _body}),
    do: "The embedding service returned HTTP #{status}."

  defp format_error({:request_failed, _reason}),
    do: "The embedding service could not be reached."

  defp format_error(reason),
    do: inspect(reason)
end
