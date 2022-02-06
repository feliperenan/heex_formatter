defmodule HeexFormatter.Formatter do
  @moduledoc false

  import Inspect.Algebra, except: [format: 2]

  # Default line length to be used in case nothing is given to the formatter as
  # options.
  @default_line_length 98

  # Reference for all inline elements so that we can tell the formatter to not
  # force a line break. This list has been taken from here:
  #
  # https://developer.mozilla.org/en-US/docs/Web/HTML/Inline_elements#list_of_inline_elements
  @inline_elements ~w(a abbr acronym audio b bdi bdo big br button canvas cite
  code data datalist del dfn em embed i iframe img input ins kbd label map
  mark meter noscript object output picture progress q ruby s samp script
  select slot small span strong sub sup svg template textarea time u tt var
  video wbr)

  @doc """
  Formats using `Inspect.Algebra` given an HTML tree built by `HTMLtree.build/1`.

  ### Rules

  ### Examples

      iex> [
      ...>   {:text, "Text only"},
      ...>   {:tag_block, "p", [], [text: "some text"]},
      ...>   {:tag_block, "section", [],
      ...>    [
      ...>      {:tag_block, "div", [],
      ...>       [
      ...>         {:tag_block, "h1", [], [text: "Hello"]},
      ...>         {:tag_block, "h2", [], [text: "Word"]}
      ...>       ]}
      ...>    ]}
      ...> ]
      iex> HeexFormatter.format(tree, [])
      ""
  """
  def format(tree, opts) do
    line_length = opts[:heex_line_length] || opts[:line_length] || @default_line_length

    formatted =
      tree
      |> block_to_algebra(opts)
      |> group()
      |> Inspect.Algebra.format(line_length)

    [formatted, ?\n]
  end

  defp block_to_algebra([], _opts), do: empty()

  defp block_to_algebra([head | tail], opts) do
    tail
    |> Enum.reduce(to_algebra(head, opts), fn node, {prev_type, prev_doc} ->
      {next_type, next_doc} = to_algebra(node, opts)

      break =
        if prev_type == :inline and next_type == :inline, do: flex_break(""), else: break("")

      {next_type, concat([prev_doc, break, next_doc])}
    end)
    |> elem(1)
  end

  defp to_algebra({:tag_block, name, attrs, block}, opts) do
    document = block_to_algebra(block, opts)
    tag_open = build_tag_open(name, attrs)

    group =
      [tag_open, nest(concat(break(""), document), 2), concat(break(""), "</#{name}>")]
      |> concat()
      |> group()

    if name in @inline_elements do
      {:inline, group}
    else
      {:block, force_unfit(group)}
    end
  end

  defp to_algebra({:text, text}, _opts) when is_binary(text) do
    {:inline, text}
  end

  # TODO: make it a tuple `{:eex, text}`
  defp to_algebra(text, _opts) when is_binary(text) do
    {:inline, "<%#{text} %>"}
  end

  defp build_tag_open(tag_name, []), do: "<#{tag_name}>"

  defp build_tag_open(tag_name, attrs) do
    attrs
    |> Enum.reduce("<#{tag_name}", &attrs_to_algebra/2)
    |> concat(">")
    |> nest(1)
    |> group()
  end

  defp attrs_to_algebra(attr, doc) do
    concat([concat(doc, break("")), " ", render_attribute(attr)])
  end

  defp render_attribute({:root, {:expr, expr, _}}), do: ~s({#{expr}})
  defp render_attribute({attr, {:string, value, _meta}}), do: ~s(#{attr}="#{value}")
  defp render_attribute({attr, {:expr, value, _meta}}), do: ~s(#{attr}={#{value}})
  defp render_attribute({attr, {_, value, _meta}}), do: ~s(#{attr}=#{value})
  defp render_attribute({attr, nil}), do: ~s(#{attr})
end
