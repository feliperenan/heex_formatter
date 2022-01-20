defmodule HeexFormatter.Phases.Tokenizer do
  @moduledoc """
  Tokenize contents using EEx.Tokenizer and Phoenix.Live.HTMLTokenizer respectively.

  Given the following contents:

  "<section>\n  <p><%= user.name ></p>\n  <%= if true do %> <p>deu bom</p><% else %><p> deu ruim </p><% end %>\n</section>\n"

  Will be tokenized as:

  [
    {:tag_open, "section", [], %{column: 1, line: 1}},
    {:text, "\n  ", %{column_end: 3, line_end: 2}},
    {:tag_open, "p", [], %{column: 3, line: 2}},
    {:eex_tag_open, "<%= user.name ></p>\n  <%= if true do %>", {block?: true, column: 6, line: 1}},
    {:text, " ", %{column_end: 2, line_end: 1}},
    {:tag_open, "p", [], %{column: 2, line: 1}},
    {:text, "deu bom", %{column_end: 12, line_end: 1}},
    {:tag_close, "p", %{column: 12, line: 1}},
    {:eex_tag_close, "<% else %>", %{column: 35, line: 2}},
    {:tag_open, "p", [], %{column: 1, line: 1}},
    {:text, " deu ruim ", %{column_end: 14, line_end: 1}},
    {:tag_close, "p", %{column: 14, line: 1}},
    {:eex_tag_close, "<% end %>", %{column: 62, line: 2}},
    {:text, "\n", %{column_end: 1, line_end: 2}},
    {:tag_close, "section", %{column: 1, line: 2}},
    {:text, "\n", %{column_end: 1, line_end: 3}}
  ]

  Notice that it adds custom identifiers to eex expresions such as `eex_tag_open`
  and `eex_tag_close` as well as `block?` metadata to indentify if that is either
  a block or not.
  """
  alias Phoenix.LiveView.HTMLTokenizer

  @spec run(String.t(), Keyword.t()) :: list()
  def run(contents, _opts) do
    {:ok, eex_nodes} = EEx.Tokenizer.tokenize(contents, 0, 0, %{indentation: 0, trim: false})
    {tokens, _acc} = Enum.flat_map_reduce(eex_nodes, [], &tokenize/2)
    tokens
  end

  defp tokenize({:text, _line, _column, text}, acc) do
    string = List.to_string(text)
    {tokens, :text} = HTMLTokenizer.tokenize(string, "nofile", 0, [], [], :text)
    {Enum.reverse(tokens), acc}
  end

  @eex_expr [:start_expr, :expr, :end_expr, :middle_expr]

  defp tokenize({type, line, column, opt, expr}, acc) when type in @eex_expr do
    render = List.to_string(opt)
    meta = %{column: column, line: line}
    expr = String.trim(to_string(expr))

    token =
      if render == "=" do
        tag = "<%= #{expr} %>"
        meta = Map.put(meta, :block?, String.ends_with?(tag, "do %>"))
        {:eex_tag_open, tag, meta}
      else
        {:eex_tag_close, "<% #{expr} %>", meta}
      end

    {[token], acc}
  end

  defp tokenize(_node, acc) do
    {[], acc}
  end
end
