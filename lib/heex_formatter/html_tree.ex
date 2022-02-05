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
    trimmed_text = String.trim(text)

    if trimmed_text == "" do
      build(tokens, buffer, stack)
    else
      build(tokens, [{:text, trimmed_text} | buffer], stack)
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

  # handle eex

  defp build([{:eex, :start_expr, expr} | tokens], buffer, stack) do
    build(tokens, [], [{:eex_block, expr, buffer} | stack])
  end

  defp build([{:eex, :middle_expr, middle_expr} | tokens], buffer, [
         {:eex_block, expr, upper_buffer, middle_buffer} | stack
       ]) do
    middle_buffer = [{Enum.reverse(buffer), middle_expr} | middle_buffer]
    build(tokens, [], [{:eex_block, expr, upper_buffer, middle_buffer} | stack])
  end

  defp build([{:eex, :middle_expr, middle_expr} | tokens], buffer, [
         {:eex_block, expr, upper_buffer} | stack
       ]) do
    middle_buffer = [{Enum.reverse(buffer), middle_expr}]
    build(tokens, [], [{:eex_block, expr, upper_buffer, middle_buffer} | stack])
  end

  defp build([{:eex, :end_expr, end_expr} | tokens], buffer, [
         {:eex_block, expr, upper_buffer, middle_buffer} | stack
       ]) do
    block = Enum.reverse([{Enum.reverse(buffer), end_expr} | middle_buffer])
    build(tokens, [{:eex_block, expr, block} | upper_buffer], stack)
  end

  defp build([{:eex, :end_expr, end_expr} | tokens], buffer, [
         {:eex_block, expr, upper_buffer} | stack
       ]) do
    block = [{Enum.reverse(buffer), end_expr}]
    build(tokens, [{:eex_block, expr, block} | upper_buffer], stack)
  end

  defp build([{:eex, _type, expr} | tokens], buffer, stack) do
    build(tokens, [expr | buffer], stack)
  end
end
