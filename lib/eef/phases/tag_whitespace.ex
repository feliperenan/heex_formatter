defmodule Eef.Phases.TagWhitespace do
  @moduledoc """
  Inspects all text nodes and "tags" leading and trailing whitespace
  by converting it into a `:space` atom or a list of `:newline` atoms.

  This is the first phase of formatting, and all other phases depend on it.
  """

  def run([_ | _] = nodes, _opts) do
    Enum.map(nodes, &tag_whitespace/1)
  end

  def run({nodes, :text}, _opts) do
    Enum.map(Enum.reverse(nodes), &tag_whitespace/1)
  end

  defp tag_whitespace({:text, text, meta}) when is_binary(text) do
    {:text, String.trim(text), meta}
  end

  defp tag_whitespace({_op, _tag, _attrs, _meta} = node) do
    node
  end

  # example: {:tag_close, "h1", %{column: 10, line: 3}}
  defp tag_whitespace({_op, _tag, _meta} = node) do
    node
  end
end
