defmodule HeexFormatter.HtmlTree do
  @moduledoc false

  # List void tags to be handled on `tag_open`.
  @void_tags ~w(area base br col hr img input link meta param command keygen source)

  @doc """
  Build an HTML Tree according to the given tokens from `Tokenizer.tokenize/1`

  This is a recursive algorithm that will build an HTML tree from a flat list of
  tokens. For instance, given this input:

  [
    {:tag_open, "div", [], %{column: 1, line: 1}},
    {:tag_open, "h1", [], %{column: 6, line: 1}},
    {:text, "Hello", %{column_end: 15, line_end: 1}},
    {:tag_close, "h1", %{column: 15, line: 1}},
    {:tag_close, "div", %{column: 20, line: 1}},
    {:tag_open, "div", [], %{column: 1, line: 2}},
    {:tag_open, "h1", [], %{column: 6, line: 2}},
    {:text, "World", %{column_end: 15, line_end: 2}},
    {:tag_close, "h1", %{column: 15, line: 2}},
    {:tag_close, "div", %{column: 20, line: 2}}
  ]

  The output will be:

  [
    {:tag_block, "div", [], [{:tag_block, "h1", [], [text: "Hello"]}]},
    {:tag_block, "div", [], [{:tag_block, "h1", [], [text: "World"]}]}
  ]

  Note that a `tag_block` has been created so that its forth argument is a list
  its nested content.

  ### How does this algorithm works?

  As this is a recursive algorithm, it starts with an empty buffer and an empty
  stack. Each will be accumulated in the buffer until it finds a `{:tag_open, ..., ...}`.

  As soon as the `tag_open` arrives, a new buffer will be started and we move
  the previous buffer to the stack along with the `tag_open`:

    ```
    defp build([{:tag_open, name, attrs, _meta} | tokens], buffer, stack) do
      build(tokens, [], [{name, attrs, buffer} | stack])
    end
    ```

  Then, we start to populate the buffer again until a `{:tag_close, ...} arrives:

    ```
    defp build([{:tag_close, name, _meta} | tokens], buffer, [{name, attrs, upper_buffer} | stack]) do
      build(tokens, [{:tag_block, name, attrs, Enum.reverse(buffer)} | upper_buffer], stack)
    end
    ```

  Here we build the `tag_block` with the accumulated buffer putting the buffer accumulated before
  the tag open (upper_buffer) on the top.

  We apply the same logic for `eex` expressions. But different from `tag_open`
  and `tag_close`, there we have `start_expr` and `end_expr` plus `middle_expr.
  The only real different is that for `eex` we also need to buil a `middle_buffer`.

  So given this eex input:

  ```elixir
  [
    {:eex, :start_expr, "if true do", %{column: 0, line: 0, opt: '='}},
    {:text, "\n  ", %{column_end: 3, line_end: 2}},
    {:eex, :expr, "\"Hello\"", %{column: 3, line: 1, opt: '='}},
    {:text, "\n", %{column_end: 1, line_end: 2}},
    {:eex, :middle_expr, "else", %{column: 1, line: 2, opt: []}},
    {:text, "\n  ", %{column_end: 3, line_end: 2}},
    {:eex, :expr, "\"World\"", %{column: 3, line: 3, opt: '='}},
    {:text, "\n", %{column_end: 1, line_end: 2}},
    {:eex, :end_expr, "end", %{column: 1, line: 4, opt: []}}
  ]
  ```

  That will be the output:

  ```elixir
  [
    {:eex_block, "if true do",
     [
       {[{:eex, "\"Hello\"", %{column: 3, line: 1, opt: '='}}], "else"},
       {[{:eex, "\"World\"", %{column: 3, line: 3, opt: '='}}], "end"}
     ]}
  ]
  ```
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
    build(tokens, [{:tag_self_close, name, attrs} | buffer], stack)
  end

  defp build([{:tag_open, name, attrs, _meta} | tokens], buffer, stack) when name in @void_tags do
    build(tokens, [{:tag_self_close, name, attrs} | buffer], stack)
  end

  defp build([{:tag_open, name, attrs, _meta} | tokens], buffer, stack) do
    build(tokens, [], [{name, attrs, buffer} | stack])
  end

  defp build([{:tag_close, name, _meta} | tokens], buffer, [{name, attrs, upper_buffer} | stack]) do
    build(tokens, [{:tag_block, name, attrs, Enum.reverse(buffer)} | upper_buffer], stack)
  end

  # handle eex

  defp build([{:eex, :start_expr, expr, _meta} | tokens], buffer, stack) do
    build(tokens, [], [{:eex_block, expr, buffer} | stack])
  end

  defp build([{:eex, :middle_expr, middle_expr, _meta} | tokens], buffer, [
         {:eex_block, expr, upper_buffer, middle_buffer} | stack
       ]) do
    middle_buffer = [{Enum.reverse(buffer), middle_expr} | middle_buffer]
    build(tokens, [], [{:eex_block, expr, upper_buffer, middle_buffer} | stack])
  end

  defp build([{:eex, :middle_expr, middle_expr, _meta} | tokens], buffer, [
         {:eex_block, expr, upper_buffer} | stack
       ]) do
    middle_buffer = [{Enum.reverse(buffer), middle_expr}]
    build(tokens, [], [{:eex_block, expr, upper_buffer, middle_buffer} | stack])
  end

  defp build([{:eex, :end_expr, end_expr, _meta} | tokens], buffer, [
         {:eex_block, expr, upper_buffer, middle_buffer} | stack
       ]) do
    block = Enum.reverse([{Enum.reverse(buffer), end_expr} | middle_buffer])
    build(tokens, [{:eex_block, expr, block} | upper_buffer], stack)
  end

  defp build([{:eex, :end_expr, end_expr, _meta} | tokens], buffer, [
         {:eex_block, expr, upper_buffer} | stack
       ]) do
    block = [{Enum.reverse(buffer), end_expr}]
    build(tokens, [{:eex_block, expr, block} | upper_buffer], stack)
  end

  defp build([{:eex, _type, expr, meta} | tokens], buffer, stack) do
    build(tokens, [{:eex, expr, meta} | buffer], stack)
  end
end
