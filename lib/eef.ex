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
    {nodes, :text} =
      contents
      |> parse_eex()
      |> HTMLTokenizer.tokenize("nofile", 0, [], [], :text)

    nodes
    |> Enum.reverse()
    |> Eef.Phases.TagWhitespace.run([])
    |> Eef.Phases.NewLines.run([])
    |> Eef.Phases.Render.run([])
    |> revert_eex_markups()
  end

  # TODO: Parse EEX since HTMLTokenizer doesn't expect it.
  defp parse_eex(contents) do
    contents
    |> then(&Regex.replace(~r/<%=(.*)%>/, &1, "<eexr>\\g{1}</eexr>"))
    |> then(&Regex.replace(~r/<%(.*)%>/, &1, "<eex>\\g{1}</eex>"))
  end

  @eex_markups [
    {"<eexr>", "<%= "},
    {"</eexr>", " %>"},
    {"<eex>", "<% "},
    {"</eex>", " %>"}
  ]
  defp revert_eex_markups(content) do
    Enum.reduce(@eex_markups, content, fn {from, to}, updated_content ->
      String.replace(updated_content, from, to)
    end)
  end
end
