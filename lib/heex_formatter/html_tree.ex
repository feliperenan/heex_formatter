defmodule HeexFormatter.HtmlTree do
  @moduledoc false

  @doc """
  Build an HTML Tree givens tokens from `Tokenizer.tokenize/1`
  """
  def build(tokens) do
    build(tokens, [], [])
  end

  defp build([], buffer, []) do
    Enum.reverse(buffer)
  end

  defp build([{:text, text, _meta} | tokens], buffer, stack) do
    # TODO: we might want to handle this in the tokenizer.
    # Ignore when it is either a new_line and/or empty spaces.
    if String.trim(text) == "" do
      build(tokens, buffer, stack)
    else
      build(tokens, [{:text, text} | buffer], stack)
    end
  end

  defp build([{:tag_open, name, attrs, %{self_close: true}} | tokens], buffer, stack) do
    build(tokens, [{:tag, name, attrs} | buffer], stack)
  end

  defp build([{:tag_open, name, attrs, _meta} | tokens], buffer, stack) do
    build(tokens, [], [{name, attrs, buffer} | stack])
  end

  defp build([{:tag_close, name, _meta} | tokens], buffer, [{name, attrs, upper_buffer} | stack]) do
    build(tokens, [{:tag_block, name, attrs, Enum.reverse(buffer)} | upper_buffer], stack)
  end

  defp build([{:eex_tag, "else", _meta} | tokens], buffer, [{expr, upper_buffer} | stack]) do
    build(tokens, [], [{expr, {Enum.reverse(buffer), "else"}, upper_buffer} | stack])
  end

  defp build([{:eex_tag, "end", _meta} | tokens], buffer, [{expr, upper_buffer} | stack]) do
    build(tokens, [{:eex_block, expr, [{Enum.reverse(buffer), "end"}]} | upper_buffer], stack)
  end

  defp build([{:eex_tag, "end", _meta} | tokens], buffer, [
         {expr, else_buffer, upper_buffer} | stack
       ]) do
    buffer = [{:eex_block, expr, [else_buffer, {Enum.reverse(buffer), "end"}]} | upper_buffer]
    build(tokens, buffer, stack)
  end

  defp build([{:eex_tag, expr, %{block?: true}} | tokens], buffer, stack) do
    build(tokens, [], [{expr, buffer} | stack])
  end

  defp build([{:eex_tag, expr, %{block?: false}} | tokens], buffer, stack) do
    build(tokens, [{:eex_tag, expr} | buffer], stack)
  end
end
