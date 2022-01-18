defmodule Eef.Phases.Render do
  @moduledoc false

  # Use 2 spaces for a tab
  @tab "  "

  @doc """
  Transform the given nodes given by LV HTML Tokenizer to string.

  ### Examples

  Given the following nodes:

  [
    {:tag_open, "section", [], %{column: 1, line: 1}},
    {:text, "\n", %{column_end: 1, line_end: 2}},
    {:tag_open, "div", [], %{column: 1, line: 2}},
    {:text, "\n", %{column_end: 1, line_end: 3}},
    {:tag_open, "h1", [], %{column: 1, line: 3}},
    {:text, "Hello", %{column_end: 10, line_end: 3}},
    {:tag_close, "h1", %{column: 10, line: 3}},
    {:text, "\n", %{column_end: 1, line_end: 4}},
    {:tag_close, "div", %{column: 1, line: 4}},
    {:text, "\n", %{column_end: 1, line_end: 5}},
    {:tag_close, "section", %{column: 1, line: 5}},
    {:text, "\n", %{column_end: 1, line_end: 6}}
  ]

  This function will return:

  "<section>\n  <div>\n    <h1>\n      Hello\n    </h1>\n  </div>\n</section>\n"

  Notice that this is already formatted. So this is supposed to be the last
  step before writting it to a file.
  """
  def run(nodes, _opts) do
    opts = %{indentation: 0}

    result =
      Enum.reduce(nodes, %{string: "", opts: opts}, fn
        {:text, "\n", _meta}, acc ->
          acc

        node, acc ->
          {node_as_string, opts} = node_to_string(node, acc.opts)

          %{acc | string: acc.string <> node_as_string, opts: opts}
      end)

    result.string
  end

  defp node_to_string({:tag_open, tag, _attrs, _}, opts) do
    # TODO: handle HTML attribues
    indent_code = indent_code(opts.indentation)
    string = "#{indent_code}<#{tag}>\n"
    opts = %{opts | indentation: opts.indentation + 1}

    {string, opts}
  end

  defp node_to_string({:text, text, _meta}, opts) do
    indent_code = indent_code(opts.indentation)
    string = indent_code <> text <> "\n"

    {string, opts}
  end

  defp node_to_string({:tag_close, tag, _meta}, opts) do
    indent_code = indent_code(opts.indentation - 1)
    string = "#{indent_code}</#{tag}>\n"

    {string, %{opts | indentation: opts.indentation - 1}}
  end

  defp indent_code(indentation) do
    String.duplicate(@tab, indentation)
  end
end
