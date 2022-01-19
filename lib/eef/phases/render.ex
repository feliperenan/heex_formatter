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
    opts = %{indentation: 0, previous_node: nil}

    result =
      Enum.reduce(nodes, %{string: "", opts: opts}, fn node, acc ->
        {node_as_string, opts} = node_to_string(node, acc.opts)
        new_string = acc.string <> node_as_string
        new_opts = %{opts | previous_node: node}

        %{acc | string: new_string, opts: new_opts}
      end)

    result.string
  end

  defp node_to_string({:tag_open, eex_tag, _attrs, _meta}, opts)
       when eex_tag in ["eexr", "eex"] do
    indentation = indent_code(opts.indentation)

    {"#{indentation}<#{eex_tag}>", opts}
  end

  defp node_to_string({:tag_open, tag, attrs, meta} = node, opts) do
    self_closed? = Map.get(meta, :self_close, false)
    indentation = indent_code(opts.indentation)

    rendered_tag =
      if put_attributes_on_separate_lines?(node) do
        tag_prefix = "#{indentation}<#{tag}\n"
        tag_suffix = if self_closed?, do: "\n#{indentation}/>", else: "\n#{indentation}>"
        attrs_indentation = indent_code(opts.indentation + 1)

        render_attribute_with_new_lines =
          attrs
          |> Enum.map(&"#{attrs_indentation}#{render_attribute(&1)}")
          |> Enum.join("\n")

        tag_prefix <> render_attribute_with_new_lines <> tag_suffix
      else
        rendered_attr =
          attrs
          |> Enum.map(&render_attribute/1)
          |> Enum.intersperse(" ")
          |> Enum.join("")

        tag_prefix = String.trim("<#{tag} #{rendered_attr}")

        if self_closed? do
          "#{indentation}#{tag_prefix} />"
        else
          "#{indentation}#{tag_prefix}>"
        end
      end

    indentation = if self_closed?, do: opts.indentation, else: opts.indentation + 1

    {rendered_tag, %{opts | indentation: indentation}}
  end

  defp node_to_string({:text, "\n", _meta}, opts) do
    {"\n", opts}
  end

  defp node_to_string({:text, text, _meta}, opts) do
    previous_node = Map.get(opts, :previous_node)

    case previous_node do
      # This is to avoid indentation in case the previous node is an eex tag.
      {:tag_open, tag, _attrs, _meta} when tag in ["eexr", "eex"] ->
        {text, opts}

      _previous_noe ->
        indentation = indent_code(opts.indentation)
        string = "\n" <> indentation <> text <> "\n"
        {string, opts}
    end
  end

  defp node_to_string({:tag_close, eex_tag, _meta}, opts)
       when eex_tag in ["eexr", "eex"] do
    {"</#{eex_tag}>", opts}
  end

  defp node_to_string({:tag_close, tag, _meta}, opts) do
    indent_code = indent_code(opts.indentation - 1)
    string = "#{indent_code}</#{tag}>"

    {string, %{opts | indentation: opts.indentation - 1}}
  end

  defp indent_code(indentation) do
    String.duplicate(@tab, indentation)
  end

  defp put_attributes_on_separate_lines?({:tag_open, tag, attrs, meta}) do
    # TODO: accept max_line_length as option.
    max_line_length = @default_line_length
    self_closed? = Map.get(meta, :self_close, false)

    # Calculate attrs length. It considers 1 space between each attribute, that
    # is why it adds + 1 for each attribute.
    attrs_length =
      attrs
      |> Enum.map(fn attr ->
        attr
        |> render_attribute()
        |> String.length()
        |> then(&(&1 + 1))
      end)
      |> Enum.sum()

    # Calculate the length of tag + attrs + spaces.
    length_on_same_line =
      attrs_length + String.length(tag) +
        if self_closed? do
          4
        else
          2
        end

    if length(attrs) > 1 do
      length_on_same_line > max_line_length
    else
      false
    end
  end

  defp render_attribute(attr) do
    case attr do
      {attr, {:string, value, _meta}} ->
        ~s(#{attr}="#{value}")

      {attr, {:expr, value, _meta}} ->
        ~s(#{attr}={#{value}})

      {attr, {_, value, _meta}} ->
        ~s(#{attr}=#{value})
    end
  end
end
