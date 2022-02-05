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
    Enum.reduce(
      tail,
      to_algebra(head, opts),
      &concat([&2, break(""), to_algebra(&1, opts)])
    )
  end

  defp to_algebra({:tag_block, name, _attrs, block}, opts) do
    document = block_to_algebra(block, opts)

    group =
      ["<#{name}>", nest(concat(break(""), document), 2), concat(break(""), "</#{name}>")]
      |> concat()
      |> group()

    if name in @inline_elements do
      group
    else
      force_unfit(group)
    end
  end

  defp to_algebra({:text, text}, _opts) when is_binary(text) do
    text
  end

  # TODO: make it a tuple `{:eex, text}`
  defp to_algebra(text, _opts) when is_binary(text) do
    "<%#{text} %>"
  end
end
