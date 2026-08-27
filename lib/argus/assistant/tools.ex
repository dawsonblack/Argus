defmodule Argus.Assistant.Tools do
  alias Argus.Assistant.Tools.ControlAppliance

  def definitions do
    [
      control_appliance_definition(),
      evaluate_math_definition()
    ]
  end

  def control_appliance_definition do
      %{
        "type" => "function",
        "function" => %{
          "name" => "control_appliance",
          "description" =>
            "Call this whenever the user wants to alter the state of a smart home appliance. Changing, activating, deactivating, turning on, turning off, or otherwise adjusting the appliance should be done through this tool.",
          "parameters" => %{
            "type" => "object",
            "properties" => %{
              "query" => %{
                "type" => "string",
                "description" =>
                  "A concise description identifying the appliance itself. Do not include the requested action."
              },
              "space" => %{
                "type" => ["string", "null"],
                "description" =>
                  "The space or room if the user specified or clearly implied one."
              },
              "action" => %{
                "type" => "string",
                "enum" => ["on", "off", "toggle", "set", "increase", "decrease"],
                "description" =>
                  "The requested operation."
              },
              "property" => %{
                "type" => ["string", "null"],
                "description" =>
                  "The appliance property being changed, such as temperature, brightness, volume, speed, or power."
              },
              "value" => %{
                "type" => ["number", "string", "null"],
                "description" =>
                  "The target value or amount of change if specified. Otherwise null."
              }
            },
            "required" => ["query", "space", "action", "property", "value"]
          }
        }
      }
  end

  def evaluate_math_definition do
      %{
        "type" => "function",
        "function" => %{
          "name" => "evaluate_math",
          "description" =>
            "Evaluate a mathematical question. Convert the user's requested calculation into valid mathematical LaTeX and call this tool. Use only the mathematical expression itself, with no prose or Markdown.",
          "parameters" => %{
            "type" => "object",
            "properties" => %{
              "latex" => %{
                "type" => "string",
                "description" =>
                  "The mathematical expression to evaluate as valid LaTeX. Do not include dollar signs, Markdown delimiters, prose, or an explanation."
              }
            },
            "required" => ["latex"]
          }
        }
      }
  end

  def execute_tool_calls(tool_calls) do
    Enum.each(tool_calls, &execute_tool_call/1)
  end

  def execute_tool_call(%{
        "function" => %{
          "name" => "control_appliance",
          "arguments" => arguments
        }
      }) do
    arguments
    |> ControlAppliance.control_appliance("house")
    |> IO.inspect(label: "CONTROL APPLIANCE RESULT")
  end

  def execute_tool_call(%{
        "function" => %{
          "name" => "evaluate_math"
        }
      }) do
    IO.puts("The user is asking a math question")
  end

  def execute_tool_call(%{
        "function" => %{
          "name" => name
        }
      }) do
    IO.puts("Unknown tool: #{name}")
  end
end
