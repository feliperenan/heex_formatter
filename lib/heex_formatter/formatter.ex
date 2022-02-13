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
  mark meter noscript object output picture progress q ruby s samp select slot
  small span strong sub sup svg template textarea time u tt var video wbr)

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
      |> block_to_algebra(:normal, opts)
      |> group()
      |> Inspect.Algebra.format(line_length)

    [formatted, ?\n]
  end

  defp block_to_algebra([], _context, _opts), do: empty()

  defp block_to_algebra([head | tail], :pre, opts) do
    Enum.reduce(tail, to_algebra(head, :pre, opts), fn node, {_prev_type, prev_doc} ->
      {next_type, next_doc} = to_algebra(node, :pre, opts)
      {next_type, concat([prev_doc, next_doc])}
    end)
    |> elem(1)
    |> group()
  end

  defp block_to_algebra([head | tail], context, opts) do
    initial = to_algebra(head, context, opts) |> maybe_force_unfit()

    Enum.reduce(tail, initial, fn node, {prev_type, prev_doc} ->
      {next_type, next_doc} = to_algebra(node, context, opts) |> maybe_force_unfit()

      cond do
        prev_type == :inline and next_type == :inline ->
          {next_type, concat([prev_doc, flex_break(""), next_doc])}

        prev_type == :newline and next_type == :inline ->
          {next_type, concat([prev_doc, line(), next_doc])}

        next_type == :newline ->
          {:text, _text, %{newlines: newlines}} = node

          if newlines > 1 do
            {next_type, concat([prev_doc, nest(line(), :reset), next_doc])}
          else
            {next_type, concat([prev_doc, next_doc])}
          end

        true ->
          {next_type, concat([prev_doc, break(""), next_doc])}
      end
    end)
    |> elem(1)
    |> group()
  end

  # TODO: Handle spaces/newlines in the beginning and at the end of the tag. At
  # the moment they are not sent by HTMLtree.
  defp to_algebra({:tag_block, "pre", attrs, block}, _context, opts) do
    children = block_to_algebra(block, :pre, opts) |> force_unfit()

    tag =
      concat([
        "<pre",
        build_attrs(attrs, opts),
        ">",
        nest(children, :reset),
        break(""),
        "</pre>"
      ])
      |> group()

    {:block, tag}
  end

  defp to_algebra({:tag_block, name, attrs, block}, context, opts) do
    {block, force_newline?} = trim_block_newlines(block)
    document = block_to_algebra(block, context, opts)
    document = if force_newline? && context != :pre, do: force_unfit(document), else: document

    group =
      concat([
        "<#{name}",
        build_attrs(attrs, opts),
        ">",
        nest(concat(break(""), document), 2),
        break(""),
        "</#{name}>"
      ])
      |> group()

    if !force_newline? and name in @inline_elements do
      {:inline, group}
    else
      {:block, group}
    end
  end

  defp to_algebra({:tag_self_close, name, attrs}, _context, opts) do
    doc = group(concat(["<#{name}", build_attrs(attrs, opts), " />"]))
    {:block, doc}
  end

  # Handle EEX blocks
  #
  # TODO: add examples as docs.
  defp to_algebra({:eex_block, expr, block}, context, opts) do
    {doc, _stab} =
      Enum.reduce(block, {empty(), false}, fn {block, expr}, {doc, stab?} ->
        {block, _force_newline?} = trim_block_newlines(block)
        {next_doc, stab?} = eex_block_to_algebra(expr, block, stab?, context, opts)
        {concat(doc, next_doc), stab?}
      end)

    doc = group(concat(["<%= #{expr} %>", doc]))

    {:block, doc}
  end

  defp to_algebra({:eex, text, %{opt: opt} = meta}, _context, opts) do
    doc = expr_to_code_algebra(text, meta, opts)
    {:inline, concat(["<%#{opt} ", doc, " %>"])}
  end

  defp to_algebra({:text, text, _meta}, :pre, _opts) when is_binary(text) do
    doc =
      text
      |> String.split(["\r\n", "\n"])
      |> Enum.map_intersperse(line(), &string(&1))
      |> concat()

    {:inline, doc}
  end

  defp to_algebra({:text, text, _meta} = node, _context, _opts) when is_binary(text) do
    if newline?(node) do
      {:newline, empty()}
    else
      {:inline,
       text
       |> String.split(["\r\n", "\n"])
       |> Enum.map(&String.trim/1)
       |> Enum.drop_while(&(&1 == ""))
       |> text_to_algebra(0, [])}
    end
  end

  # Empty newline
  defp text_to_algebra(["" | lines], newlines, acc),
    do: text_to_algebra(lines, newlines + 1, acc)

  # Text
  # Text
  defp text_to_algebra([line | lines], 0, acc),
    do: text_to_algebra(lines, 0, [string(line), line() | acc])

  # Text
  #
  # Text
  defp text_to_algebra([line | lines], _newlines, acc),
    do: text_to_algebra(lines, 0, [string(line), line(), nest(line(), :reset) | acc])

  # Final clause: single line
  defp text_to_algebra([], _, [doc, _line]),
    do: doc

  # Final clause: multiple lines
  defp text_to_algebra([], _, acc),
    do: acc |> Enum.reverse() |> tl() |> concat() |> force_unfit()

  defp build_attrs([], _opts), do: empty()

  defp build_attrs(attrs, opts) do
    attrs
    |> Enum.reduce(empty(), &concat([&2, break(" "), render_attribute(&1, opts)]))
    |> nest(2)
    |> concat(break(""))
    |> group()
  end

  defp render_attribute({:root, {:expr, expr, _}}, _opts), do: ~s({#{expr}})
  defp render_attribute({attr, {:string, value, _meta}}, _opts), do: ~s(#{attr}="#{value}")

  defp render_attribute({attr, {:expr, value, meta}}, opts) do
    expr =
      break("")
      |> concat(expr_to_code_algebra(value, meta, opts))
      |> nest(2)

    concat(["#{attr}={", expr, concat(break(""), "}")])
    |> group()
  end

  defp render_attribute({attr, {_, value, _meta}}, _opts), do: ~s(#{attr}=#{value})
  defp render_attribute({attr, nil}, _opts), do: ~s(#{attr})

  # Handle cond/case first clause.
  #
  # {[], "something ->"}
  defp eex_block_to_algebra(expr, [], _stab?, _context, _opts) do
    {break("")
     |> concat("<% #{expr} %>")
     |> nest(2), true}
  end

  # Handle Eex else, end and case/cond expressions.
  #
  # {[{:tag_block, "p", [], [text: "do something"]}], "else"}
  defp eex_block_to_algebra(expr, block, stab?, context, opts) when is_list(block) do
    indent = if stab?, do: 4, else: 2

    document =
      break("")
      |> concat(block_to_algebra(block, context, opts))
      |> nest(indent)

    stab? = String.ends_with?(expr, "->")
    indent = if stab?, do: 2, else: 0

    next =
      break("")
      |> concat("<% #{expr} %>")
      |> nest(indent)

    {concat(document, next), stab?}
  end

  defp expr_to_code_algebra(expr, meta, opts) do
    string_to_quoted_opts = [
      literal_encoder: &{:ok, {:__block__, &2, [&1]}},
      token_metadata: true,
      unescape: false,
      line: meta.line,
      column: meta.column
    ]

    expr
    |> Code.string_to_quoted!(string_to_quoted_opts)
    |> Code.quoted_to_algebra(Keyword.merge(opts, escape: false))
  end

  defp newline?({:text, text, _meta}), do: String.trim_leading(text) == ""
  defp newline?(_node), do: false

  defp maybe_force_unfit({:block, doc}), do: {:block, force_unfit(doc)}
  defp maybe_force_unfit(doc), do: doc

  defp trim_block_newlines(block) do
    {tail, force?} = pop_head_if_only_spaces_or_newlines(block)

    {block, _} =
      tail
      |> Enum.reverse()
      |> pop_head_if_only_spaces_or_newlines()

    force? = if Enum.empty?(block), do: false, else: force?

    {Enum.reverse(block), force?}
  end

  defp pop_head_if_only_spaces_or_newlines([{:text, text, meta} | tail] = block) do
    force? = meta.newlines > 0
    if String.trim_leading(text) == "", do: {tail, force?}, else: {block, force?}
  end

  defp pop_head_if_only_spaces_or_newlines(block), do: {block, false}
end
