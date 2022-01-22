defmodule HeexFormatter.Phases.Tokenizer do
  @moduledoc """
  Tokenize contents using EEx.Tokenizer and Phoenix.Live.HTMLTokenizer respectively.

  Given the following contents:

  "<section>\n  <p><%= user.name ></p>\n  <%= if true do %> <p>deu bom</p><% else %><p> deu ruim </p><% end %>\n</section>\n"

  Will be tokenized as:

  [
    {:tag_open, "section", [], %{column: 1, line: 1}},
    {:tag_open, "p", [], %{column: 3, line: 2}},
    {:eex_tag_render, "<%= user.name ></p>\n  <%= if true do %>", {block?: true, column: 6, line: 1}},
    {:text, " ", %{column_end: 2, line_end: 1}},
    {:tag_open, "p", [], %{column: 2, line: 1}},
    {:text, "deu bom", %{column_end: 12, line_end: 1}},
    {:tag_close, "p", %{column: 12, line: 1}},
    {:eex_tag, "<% else %>", %{column: 35, line: 2}},
    {:tag_open, "p", [], %{column: 1, line: 1}},
    {:text, " deu ruim ", %{column_end: 14, line_end: 1}},
    {:tag_close, "p", %{column: 14, line: 1}},
    {:eex_tag, "<% end %>", %{column: 62, line: 2}},
    {:tag_close, "section", %{column: 1, line: 2}},
  ]

  Notice that it adds custom identifiers to eex expressions such as `eex_tag_render` and
  `eex_tag` as well as `block?` metadata to identify if that is either a block or not.
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
    {tokens, _} = HTMLTokenizer.tokenize(string, "nofile", 0, [], [], :text)
    {tokens |> Enum.reject(&line_break?/1) |> Enum.reverse(), acc}
  end

  @eex_expr [:start_expr, :expr, :end_expr, :middle_expr]

  defp tokenize({type, line, column, opt, expr}, acc) when type in @eex_expr do
    render = List.to_string(opt)
    expr = expr |> List.to_string() |> String.trim()
    block? = String.ends_with?(expr, "do") || String.ends_with?(expr, "->")
    meta = %{column: column, line: line, block?: block?}

    {type, tag} =
      if render == "=" do
        {:eex_tag_render, "<%= #{expr} %>"}
      else
        {:eex_tag, "<% #{expr} %>"}
      end

    {[{type, tag, meta}], acc}
  end

  defp tokenize(_node, acc) do
    {[], acc}
  end

  defp line_break?({:text, text, _meta}) do
    String.trim(text) == ""
  end

  defp line_break?(_node), do: false
end
