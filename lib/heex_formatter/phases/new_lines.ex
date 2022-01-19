defmodule HeexFormatter.Phases.NewLines do
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
    result = Enum.reduce(nodes, initial_state, &may_add_new_line/2)
    result.nodes
  end

  defp may_add_new_line({:text, _text, _meta} = node, acc) do
    update_state(acc, [node], node)
  end

  defp may_add_new_line(node, acc) do
    case acc.previous do
      nil ->
        update_state(acc, [node], node)

      {:text, _text, _meta} ->
        update_state(acc, [node], node)

      _node ->
        if acc.index + 1 == acc.length do
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
end
