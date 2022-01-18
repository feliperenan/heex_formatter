defmodule Eef.Phases.TagWhitespace do
  @moduledoc false

  @doc """
  [
    {:tag_open, "section", [], %{column: 1, line: 1}},
    {:text, "\n", %{column_end: 1, line_end: 2}},
    {:tag_open, "div", [], %{column: 1, line: 2}},
    {:text, "\n", %{column_end: 1, line_end: 3}},
    {:tag_open, "h1", [], %{column: 1, line: 3}},
    {:text, "Hello", %{column_end: 10, line_end: 3}},
  ]
  """
  def run(nodes, _opts) do
    Enum.map(nodes, &tag_whitespace/1)
  end

  # Trim the given text but keep line breaks eg \n.
  defp tag_whitespace({:text, text, meta}) when is_binary(text) do
    text = Regex.replace(~r/^ +| +$/, text, "")
    {:text, text, meta}
  end

  defp tag_whitespace(node), do: node
end
