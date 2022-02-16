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
  def format(tree, opts) when is_list(tree) do
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

    group =
      concat([
        "<#{name}",
        build_attrs(attrs),
        ">",
        nest(concat(break(""), document), 2),
        break(""),
        "</#{name}>"
      ])
      |> group()

    if name in @inline_elements do
      {:inline, group}
    else
      {:block, force_unfit(group)}
    end
  end

  defp to_algebra({:tag_self_close, name, attrs}, _opts) do
    doc = group(concat(["<#{name}", build_attrs(attrs), " />"]))
    {:block, force_unfit(doc)}
  end

  # Handle EEX blocks
  #
  # TODO: add examples as docs.
  defp to_algebra({:eex_block, expr, block}, opts) do
    {doc, _stab} =
      Enum.reduce(block, {empty(), false}, fn node, {doc, stab?} ->
        {next_doc, stab?} = eex_block_to_algebra(node, stab?, opts)
        {concat(doc, next_doc), stab?}
      end)

    doc =
      concat(["<%= #{expr} %>", doc])
      |> group()
      |> force_unfit()

    {:block, doc}
  end

  defp to_algebra({:eex, text, %{opt: opt, column: column, line: line}}, opts) do
    string_to_quoted_opts = [
      literal_encoder: &{:ok, {:__block__, &2, [&1]}},
      token_metadata: true,
      unescape: false,
      line: line,
      column: column
    ]

    doc =
      text
      |> Code.string_to_quoted!(string_to_quoted_opts)
      |> Code.quoted_to_algebra(Keyword.merge(opts, escape: false))

    {:inline, concat(["<%#{opt} ", doc, " %>"])}
  end

  defp to_algebra({:text, text}, _opts) when is_binary(text) do
    {:inline, text}
  end

  defp build_attrs([]), do: empty()

  defp build_attrs(attrs) do
    attrs
    |> Enum.reduce(empty(), &concat([&2, break(" "), render_attribute(&1)]))
    |> nest(2)
    |> concat(break(""))
    |> group()
  end

  defp render_attribute({:root, {:expr, expr, _}}), do: ~s({#{expr}})
  defp render_attribute({attr, {:string, value, _meta}}), do: ~s(#{attr}="#{value}")
  defp render_attribute({attr, {:expr, value, _meta}}), do: ~s(#{attr}={#{value}})
  defp render_attribute({attr, {_, value, _meta}}), do: ~s(#{attr}=#{value})
  defp render_attribute({attr, nil}), do: ~s(#{attr})

  # Handle cond/case first clause.
  #
  # {[], "something ->"}
  defp eex_block_to_algebra({[], expr}, _stab?, _opts) do
    {break("")
     |> concat("<% #{expr} %>")
     |> nest(2), true}
  end

  # Handle Eex else, end and case/cond expressions.
  #
  # {[{:tag_block, "p", [], [text: "do something"]}], "else"}
  defp eex_block_to_algebra({block, expr}, stab?, opts) when is_list(block) do
    indent = if stab?, do: 4, else: 2

    document =
      break("")
      |> concat(block_to_algebra(block, opts))
      |> nest(indent)

    stab? = String.ends_with?(expr, "->")
    indent = if stab?, do: 2, else: 0

    next =
      break("")
      |> concat("<% #{expr} %>")
      |> nest(indent)

    {concat(document, next), stab?}
  end
end
