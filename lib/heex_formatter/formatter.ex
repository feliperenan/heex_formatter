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

      cond do
        prev_type == :inline and next_type == :inline ->
          {next_type, concat([prev_doc, flex_break(""), next_doc])}

        prev_type == :newline and next_type == :inline ->
          {next_type, concat([prev_doc, line(), next_doc])}

        next_type == :newline ->
          if multiple_newlines?(node) do
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

  defp to_algebra({:tag_block, name, attrs, block, %{force_newline?: force_newline?}}, opts) do
    document = block_to_algebra(block, opts)
    document = if force_newline?, do: force_unfit(document), else: document

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
      {:block, force_unfit(group)}
    end
  end

  defp to_algebra({:tag_self_close, name, attrs}, opts) do
    doc = group(concat(["<#{name}", build_attrs(attrs, opts), " />"]))
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

  defp to_algebra({:eex, text, %{opt: opt} = meta}, opts) do
    doc = expr_to_code_algebra(text, meta, opts)
    {:inline, concat(["<%#{opt} ", doc, " %>"])}
  end

  defp to_algebra({:text, text} = node, _opts) when is_binary(text) do
    cond do
      # Check if the given node is new line: `{:text, "\n\n"}` and if so, we
      # want to ignore it in the concatenation but sinalize that there is a
      # newline.
      newline?(node) ->
        {:newline, empty()}

      # Check if the given text starts with a new line: `{:text, "\nText Text"}`
      # and if so, we want to force unfit it.
      String.starts_with?(text, "\n") ->
        {:inline, text |> String.trim() |> string() |> force_unfit()}

      true ->
        # We shouldn't trim it here but try to compute the indetation as suggested
        # by this gist: https://gist.github.com/josevalim/69366f804f867fe13c9d44743db9be4a
        # in order to handle script/styles and maybe HTML comments.
        {:inline, text |> String.trim() |> string()}
    end
  end

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
  defp eex_block_to_algebra({[], expr, _meta}, _stab?, _opts) do
    {break("")
     |> concat("<% #{expr} %>")
     |> nest(2), true}
  end

  # Handle Eex else, end and case/cond expressions.
  #
  # {[{:tag_block, "p", [], [text: "do something"]}], "else"}
  defp eex_block_to_algebra({block, expr, _meta}, stab?, opts) when is_list(block) do
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

  defp newline?({:text, text}), do: String.trim_trailing(text) == ""
  defp newline?(_node), do: false

  defp multiple_newlines?({:text, text}) do
    newlines_count = text |> String.graphemes() |> Enum.count(&(&1 == "\n"))
    newlines_count > 1
  end
end
