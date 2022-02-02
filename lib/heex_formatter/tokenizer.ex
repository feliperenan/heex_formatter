defmodule HeexFormatter.Tokenizer do
  @moduledoc false

  alias Phoenix.LiveView.HTMLTokenizer

  @doc """
  Tokenize contents using EEx.Tokenizer and Phoenix.Live.HTMLTokenizer respectively.

  Given the following contents:

  "<section>\n  <p><%= user.name ></p>\n  <%= if true do %> <p>deu bom</p><% else %><p> deu ruim </p><% end %>\n</section>\n"

  Will be tokenized as:

  [
    {:tag_open, "section", [], %{column: 1, line: 1}},
    {:text, "\n  ", %{column_end: 3, line_end: 2}},
    {:tag_open, "p", [], %{column: 3, line: 2}},
    {:eex_tag_render, "<%= user.name ></p>\n  <%= if true do %>", %{block?: true, column: 6, line: 1}},
    {:text, " ", %{column_end: 2, line_end: 1}},
    {:tag_open, "p", [], %{column: 2, line: 1}},
    {:text, "deu bom", %{column_end: 12, line_end: 1}},
    {:tag_close, "p", %{column: 12, line: 1}},
    {:eex_tag, "<% else %>", %{block?: false, column: 35, line: 2}},
    {:tag_open, "p", [], %{column: 1, line: 1}},
    {:text, " deu ruim ", %{column_end: 14, line_end: 1}},
    {:tag_close, "p", %{column: 14, line: 1}},
    {:eex_tag, "<% end %>", %{block?: false, column: 62, line: 2}},
    {:text, "\n", %{column_end: 1, line_end: 2}},
    {:tag_close, "section", %{column: 1, line: 2}}
  ]

  Notice that it adds custom identifiers to eex expressions such as `eex_tag_render` and
  `eex_tag` as well as `block?` metadata to identify if that is either a block or not.
  """
  def tokenize(contents) do
    {:ok, eex_nodes} = EEx.Tokenizer.tokenize(contents, 0, 0, %{indentation: 0, trim: false})
    {tokens, cont} = Enum.reduce(eex_nodes, {[], :text}, &do_tokenize/2)
    HTMLTokenizer.finalize(tokens, "nofile", cont)
  end

  defp do_tokenize({:text, _line, _column, text}, {tokens, cont}) do
    text
    |> List.to_string()
    |> HTMLTokenizer.tokenize("nofile", 0, [], tokens, cont)
  end

  @eex_expr [:start_expr, :expr, :end_expr, :middle_expr]

  defp do_tokenize({type, line, column, opt, expr}, {tokens, cont}) when type in @eex_expr do
    expr = [opt, expr] |> IO.iodata_to_binary() |> String.trim()
    meta = %{column: column, line: line, block?: String.ends_with?(expr, "do")}

    {[{:eex_tag, type, expr, meta} | tokens], cont}
  end

  defp do_tokenize(_node, acc) do
    acc
  end
end
