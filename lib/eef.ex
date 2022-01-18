defmodule Eef do
  @moduledoc """
  Documentation for `Eef`.
  """
  @behaviour Mix.Tasks.Format

  alias Phoenix.LiveView.HTMLTokenizer

  @impl Mix.Tasks.Format
  def features(_opts) do
    [sigils: [:H], extensions: [".heex"]]
  end

  @impl Mix.Tasks.Format
  def format(contents, _opts) do
    IO.inspect(contents, label: "input")

    {nodes, :text} = HTMLTokenizer.tokenize(contents, "nofile", 0, [], [], :text)

    nodes
    |> Enum.reverse()
    # |> Eef.Phases.TagWhitespace.run([])
    |> Eef.Phases.Render.run([])
    |> IO.inspect(label: "output")
  end

  # TODO: Parse EEX since HTMLTokenizer doesn't expect it.
  # defp parse_eex(contents) do
  #   contents
  #   |> String.replace("<%=", "")
  #   |> String.replace("<%", "")
  #   |> String.replace("%>", "")
  # end
end
