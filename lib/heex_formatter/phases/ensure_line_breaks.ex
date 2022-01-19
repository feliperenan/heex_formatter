defmodule HeexFormatter.Phases.EnsureLineBreaks do
  @moduledoc false

  @doc """
  Add line breakes after every tag open or tag close.

  ### Examples

  Given this input:

  [
    {:tag_open, "section", [], %{column: 1, line: 1}},
    {:tag_open, "div", [], %{column: 10, line: 1}},
    {:tag_open, "h1", [], %{column: 15, line: 1}},
    {:text, "Hello", %{column_end: 24, line_end: 1}},
    {:tag_close, "h1", %{column: 24, line: 1}},
    {:tag_close, "div", %{column: 29, line: 1}},
    {:tag_close, "section", %{column: 35, line: 1}}
  ]

  That's the output:

  [
    {:tag_open, "section", [], %{column: 1, line: 1}},
    {:text, "\n", %{}},
    {:tag_open, "div", [], %{column: 10, line: 1}},
    {:text, "\n", %{}},
    {:tag_open, "h1", [], %{column: 15, line: 1}},
    {:text, "Hello", %{column_end: 24, line_end: 1}},
    {:tag_close, "h1", %{column: 24, line: 1}},
    {:text, "\n", %{}},
    {:tag_close, "div", %{column: 29, line: 1}},
    {:text, "\n", %{}},
    {:tag_close, "section", %{column: 35, line: 1}},
    {:text, "\n", %{column_end: 1, line_end: 2}}
  ]

  Notice {:text, "\n", %{}} right after each `tag_open` or `tag_close`.
  """
  def run(nodes, _opts) do
    initial_state = %{nodes: [], previous: nil, index: 0, length: length(nodes)}
    result = Enum.reduce(nodes, initial_state, &ensure_correct_line_breaks/2)
    result.nodes
  end

  defp ensure_correct_line_breaks({:text, text, meta} = node, acc) do
    cond do
      # In case it is a line break and it is the last interaction, we want to keep
      # this line break in the end of the nodes.
      line_break?(node) and last_interaction?(acc) ->
        update_state(acc, [{:text, "\n", meta}], acc.previous)

      # Skip this node in case this is a line break so that we will keep just one
      # line break among tags.
      line_break?(node) ->
        update_state(acc, [], acc.previous)

      # Here we know that it is not a line break so we can safely trim it to
      # remove extra spaces from the string.
      true ->
        update_state(acc, [{:text, String.trim(text), meta}], node)
    end
  end

  defp ensure_correct_line_breaks(node, acc) do
    case acc.previous do
      nil ->
        update_state(acc, [node], node)

      {:text, _text, _meta} ->
        update_state(acc, [node], node)

      _node ->
        if last_interaction?(acc) do
          update_state(acc, [node], node)
        else
          new_line = {:text, "\n", %{}}
          update_state(acc, [new_line, node], node)
        end
    end
  end

  defp update_state(state, nodes, previous) do
    %{
      state
      | nodes: state.nodes ++ nodes,
        previous: previous,
        index: state.index + 1
    }
  end

  defp last_interaction?(state) do
    state.index + 1 == state.length
  end

  defp line_break?({:text, text, _meta}) do
    String.trim(text) == ""
  end

  defp line_break?(_node), do: false
end
