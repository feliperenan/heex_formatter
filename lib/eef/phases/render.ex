defmodule Eef.Phases.Render do
  @moduledoc false

  # Use 2 spaces for a tab
  @tab "  "

  # Line length of opening tags before splitting attributes onto their own line
  @default_line_length 98

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

  defp node_to_string({:tag_open, tag, attrs, meta}, opts) do
    # TODO: accept max_line_length as option.
    max_line_length = @default_line_length
    self_closed? = Map.get(meta, :self_close, false)
    indentation = indent_code(opts.indentation)

    attrs_as_string =
      Enum.reduce(attrs, "", fn
        {attr, {:string, value, _meta}}, acc ->
          ~s(#{acc}#{attr}="#{value}" )

        {attr, {:expr, value, _meta}}, acc ->
          ~s(#{acc}#{attr}={#{value}} )

        {attr, {_, value, _meta}}, acc ->
          ~s(#{acc}#{attr}=#{value} )
      end)

    # calculate length of the entire opening tag if fit on a single line
    attrs_length = String.length(attrs_as_string)

    # Check if there is more than one attribute and if so, check it fits in the
    # same line.
    length_on_same_line =
      attrs_length + String.length(tag) +
        if self_closed? do
          4
        else
          2
        end

    put_attributes_on_separate_lines? =
      if length(attrs) > 1 do
        length_on_same_line > max_line_length
      else
        false
      end

    if put_attributes_on_separate_lines? do
      tag_prefix = "#{indentation}<#{tag}\n"
      attrs_indentation = indent_code(opts.indentation + 1)

      attrs_with_new_lines =
        Enum.reduce(attrs, "", fn
          {attr, {:string, value, _meta}}, acc ->
            "#{acc}#{attrs_indentation}" <> ~s(#{attr}="#{value}"\n)

          {attr, {:expr, value, _meta}}, acc ->
            "#{acc}#{attrs_indentation}" <> ~s(#{attr}={#{value}}\n)

          {attr, {_, value, _meta}}, acc ->
            "#{acc}#{attrs_indentation}" <> ~s(#{attr}=#{value}\n)
        end)

      tag_suffix = "#{indentation}/>\n"

      tag_as_string = tag_prefix <> attrs_with_new_lines <> tag_suffix

      {tag_as_string, opts.indentation + 1}
    else
      contain_attrs? = attrs_as_string != ""

      tag_as_string =
        case {contain_attrs?, self_closed?} do
          {true, true} ->
            "#{indentation}<#{tag} #{attrs_as_string}/>\n"

          {true, false} ->
            "#{indentation}<#{tag} #{attrs_as_string}>\n"

          {false, false} ->
            "#{indentation}<#{tag}>\n"

          {false, true} ->
            "#{indentation}<#{tag} />\n"
        end

      opts = %{opts | indentation: opts.indentation + 1}

      {tag_as_string, opts}
    end
  end

  defp node_to_string({:text, text, _meta}, opts) do
    indentation = indent_code(opts.indentation)
    string = indentation <> text <> "\n"

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
