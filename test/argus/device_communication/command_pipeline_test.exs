defmodule Argus.DeviceCommunication.CommandPipelineTest do
  use ExUnit.Case, async: true

  alias Argus.DeviceCommunication.CommandPipeline

  test "applies a full JSON-style pipeline to a value" do
    pipeline = [
      ["min", 1],
      ["add", 1],
      ["reverse", 1]
    ]

    result = CommandPipeline.apply_value_pipeline(pipeline, 50)

    assert result == [1, 2]  # 49 = "1" in ASCII, then reversed and binary-encoded
  end
end
