defmodule HeexFormatter do
  @moduledoc """
  Format Heex templates from `.heex` files or `~H` sigils.

  This is a plugin for Mix format:

  https://hexdocs.pm/mix/main/Mix.Tasks.Format.html#module-plugins

  ### Setup

  Add this project as a dependency in your `mix.exs` file.

  defp deps do
    [
      # ...
      {:heex_formatter, github: "feliperenan/heex_formatter"}
    ]
  end

  Add it as plugin to your project `.formatter` file and make sure to put the`heex` extension in
  the `inputs` option.

  ```elixir
  [
    plugins: [HeexFormatter],
    inputs: ["*.{heex,ex,exs}", "priv/*/seeds.exs", "{config,lib,test}/**/*.{heex,ex,exs}"],
    # ...
  ]
  ```

  ### options

  * `line_length`: The Elixir formatter defaults to a maximum line length of 98 characters,
    which can be overwritten with the `line_length` option in your `.formatter` file.

    Set `heex_line_length` to only set the line length for the heex formatter.

    ```elixir
    [
      # ...omitted
      heex_line_length: 300
    ]
    ```

  ### Formatting

  This formatter tries to be as consistent as possible with the Elixir formatter.
  With that being said, you should expect a similar formatting experience.

  Given HTML like this:

  ```eex
    <section><h1>   <b>Hello</b></h1> </section>
  ```

  It will be formatted as:

  ```eex
  <section>
    <h1><b><%= @user.name %></b></h1>
  </section>
  ```

  A block element will go to the next line, while inline elements will be kept in the current line
  as long as they fit within the configured line length.

  The following links list all block and inline elements.

  https://developer.mozilla.org/en-US/docs/Web/HTML/Block-level_elements#elements
  https://developer.mozilla.org/en-US/docs/Web/HTML/Inline_elements#list_of_inline_elements

  It will also keep inline elements in their own lines if you intentionally write them this way:

  ```eex
  <section>
    <h1>
      <b><%= @user.name %></b>
    </h1>
  </section>
  ```

  This formatter will place all attributes on their own lines when they do not all fit in the
  current line.

  Therefore this:

  ```eex
  <section id="user-section-id" class="sm:focus:block flex w-full p-3" phx-click="send-event">
    <p>Hi</p>
  </section>
  ```

  Will be formatted to:

  ```eex
  <section
    id="user-section-id"
    class="sm:focus:block flex w-full p-3"
    phx-click="send-event">
    <p>Hi</p>
  </section>
  ```

  ### Intentional new lines

  The formatter will keep intentional new lines. In fact, the formatter will
  always keep a maximum of one line break in case you have multiple ones:

  ```eex
  <section>


    <h1>
      <%= Hello %>
    </h1>

  </section>
  ```

  Will become:

  ```eex
  <section>

    <h1>
      <%= Hello %>
    </h1>

  </section>
  ```

  It also won't keep multiple lines between texts:

  ```
  <p>
    text


    text
  </p>
  ```

  Will be formatted to:

  ```
  <p>
    text

    text
  </p>
  ```
  """
  alias HeexFormatter.Algebra
  alias Phoenix.LiveView.HTMLTokenizer

  # Default line length to be used in case nothing is specified in the `.formatter` options.
  @default_line_length 98

  @behaviour Mix.Tasks.Format

  @impl Mix.Tasks.Format
  def features(_opts) do
    [sigils: [:H], extensions: [".heex"]]
  end

  @impl Mix.Tasks.Format
  def format(contents, opts) do
    line_length = opts[:heex_line_length] || opts[:line_length] || @default_line_length

    formatted =
      contents
      |> tokenize()
      |> to_tree()
      |> Algebra.build(opts)
      |> Inspect.Algebra.format(line_length)

    # If the opening delimiter is a single character, such as ~H"...",
    # do not add trailing newline.
    newline = if match?(<<_>>, opts[:opening_delimiter]), do: [], else: ?\n

    # TODO: Remove IO.iodata_to_binary/1 call on Elixir v1.14+
    IO.iodata_to_binary([formatted, newline])
  end

  # Tokenize contents using EEx.Tokenizer and Phoenix.Live.HTMLTokenizer respectively.
  #
  # The following content:
  #
  # "<section>\n  <p><%= user.name ></p>\n  <%= if true do %> <p>deu bom</p><% else %><p> deu ruim </p><% end %>\n</section>\n"
  #
  # Will be tokenized as:
  #
  # [
  #   {:tag_open, "section", [], %{column: 1, line: 1}},
  #   {:text, "\n  ", %{column_end: 3, line_end: 2}},
  #   {:tag_open, "p", [], %{column: 3, line: 2}},
  #   {:eex_tag_render, "<%= user.name ></p>\n  <%= if true do %>", %{block?: true, column: 6, line: 1}},
  #   {:text, " ", %{column_end: 2, line_end: 1}},
  #   {:tag_open, "p", [], %{column: 2, line: 1}},
  #   {:text, "deu bom", %{column_end: 12, line_end: 1}},
  #   {:tag_close, "p", %{column: 12, line: 1}},
  #   {:eex_tag, "<% else %>", %{block?: false, column: 35, line: 2}},
  #   {:tag_open, "p", [], %{column: 1, line: 1}},
  #   {:text, " deu ruim ", %{column_end: 14, line_end: 1}},
  #   {:tag_close, "p", %{column: 14, line: 1}},
  #   {:eex_tag, "<% end %>", %{block?: false, column: 62, line: 2}},
  #   {:text, "\n", %{column_end: 1, line_end: 2}},
  #   {:tag_close, "section", %{column: 1, line: 2}}
  # ]
  defp tokenize(contents) do
    # EEx.tokenize/2 was introduced in Elixir 1.14.
    # TODO: Remove this when we no longer support earlier versions.
    {:ok, eex_nodes} =
      if Code.ensure_loaded?(EEx) && function_exported?(EEx, :tokenize, 2) do
        EEx.tokenize(contents)
      else
        EEx.Tokenizer.tokenize(contents, 1, 0, %{indentation: 0, trim: false})
      end

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
    meta = %{opt: opt, line: line, column: column}
    {[{:eex, type, expr |> List.to_string() |> String.trim(), meta} | tokens], cont}
  end

  defp do_tokenize(_node, acc) do
    acc
  end

  # Build an HTML Tree according to the tokens from the EEx and HTML tokenizers.
  #
  # This is a recursive algorithm that will build an HTML tree from a flat list of
  # tokens. For instance, given this input:
  #
  # [
  #   {:tag_open, "div", [], %{column: 1, line: 1}},
  #   {:tag_open, "h1", [], %{column: 6, line: 1}},
  #   {:text, "Hello", %{column_end: 15, line_end: 1}},
  #   {:tag_close, "h1", %{column: 15, line: 1}},
  #   {:tag_close, "div", %{column: 20, line: 1}},
  #   {:tag_open, "div", [], %{column: 1, line: 2}},
  #   {:tag_open, "h1", [], %{column: 6, line: 2}},
  #   {:text, "World", %{column_end: 15, line_end: 2}},
  #   {:tag_close, "h1", %{column: 15, line: 2}},
  #   {:tag_close, "div", %{column: 20, line: 2}}
  # ]
  #
  # The output will be:
  #
  # [
  #   {:tag_block, "div", [], [{:tag_block, "h1", [], [text: "Hello"]}]},
  #   {:tag_block, "div", [], [{:tag_block, "h1", [], [text: "World"]}]}
  # ]
  #
  # Note that a `tag_block` has been created so that its fourth argument is a list of
  # its nested content.
  #
  # ### How does this algorithm work?
  #
  # As this is a recursive algorithm, it starts with an empty buffer and an empty
  # stack. Each will be accumulated in the buffer until it finds a `{:tag_open, ..., ...}`.
  #
  # As soon as the `tag_open` arrives, a new buffer will be started and we move
  # the previous buffer to the stack along with the `tag_open`:
  #
  #   ```
  #   defp build([{:tag_open, name, attrs, _meta} | tokens], buffer, stack) do
  #     build(tokens, [], [{name, attrs, buffer} | stack])
  #   end
  #   ```
  #
  # Then, we start to populate the buffer again until a `{:tag_close, ...} arrives:
  #
  #   ```
  #   defp build([{:tag_close, name, _meta} | tokens], buffer, [{name, attrs, upper_buffer} | stack]) do
  #     build(tokens, [{:tag_block, name, attrs, Enum.reverse(buffer)} | upper_buffer], stack)
  #   end
  #   ```
  #
  # Here we build the `tag_block` with the accumulated buffer, placing the buffer accumulated
  # before the tag open (upper_buffer) on top.
  #
  # We apply the same logic for `eex` expressions but, instead of `tag_open` and `tag_close`, here
  # we have `start_expr` and `end_expr` plus `middle_expr`. The only real difference is that for
  # `eex` we also need to build a `middle_buffer`.
  #
  # So given this eex input:
  #
  # ```elixir
  # [
  #   {:eex, :start_expr, "if true do", %{column: 0, line: 0, opt: '='}},
  #   {:text, "\n  ", %{column_end: 3, line_end: 2}},
  #   {:eex, :expr, "\"Hello\"", %{column: 3, line: 1, opt: '='}},
  #   {:text, "\n", %{column_end: 1, line_end: 2}},
  #   {:eex, :middle_expr, "else", %{column: 1, line: 2, opt: []}},
  #   {:text, "\n  ", %{column_end: 3, line_end: 2}},
  #   {:eex, :expr, "\"World\"", %{column: 3, line: 3, opt: '='}},
  #   {:text, "\n", %{column_end: 1, line_end: 2}},
  #   {:eex, :end_expr, "end", %{column: 1, line: 4, opt: []}}
  # ]
  # ```
  #
  # The output will be:
  #
  # ```elixir
  # [
  #   {:eex_block, "if true do",
  #    [
  #      {[{:eex, "\"Hello\"", %{column: 3, line: 1, opt: '='}}], "else"},
  #      {[{:eex, "\"World\"", %{column: 3, line: 3, opt: '='}}], "end"}
  #    ]}
  # ]
  # ```
  def to_tree(tokens) do
    to_tree(tokens, [], [])
  end

  defp to_tree([], buffer, []) do
    Enum.reverse(buffer)
  end

  defp to_tree([{:text, text, %{context: [:comment_start]}} | tokens], buffer, stack) do
    to_tree(tokens, [], [{:comment, text, buffer} | stack])
  end

  defp to_tree([{:text, text, %{context: [:comment_end]}} | tokens], buffer, [
         {:comment, start_text, upper_buffer} | stack
       ]) do
    buffer = Enum.reverse([{:text, String.trim_trailing(text), %{}} | buffer])

    to_tree(
      tokens,
      [{:html_comment, [{:text, String.trim_leading(start_text), %{}} | buffer]} | upper_buffer],
      stack
    )
  end

  defp to_tree(
         [{:text, text, %{context: [:comment_start, :comment_end]}} | tokens],
         buffer,
         stack
       ) do
    to_tree(tokens, [{:comment, text} | buffer], stack)
  end

  defp to_tree([{:text, text, _meta} | tokens], buffer, stack) do
    if inline_comment?(text) do
      to_tree(tokens, [{:comment, text} | buffer], stack)
    else
      meta = %{newlines: count_newlines_until_text(text, 0)}
      to_tree(tokens, [{:text, text, meta} | buffer], stack)
    end
  end

  defp to_tree([{:tag_open, name, attrs, %{self_close: true}} | tokens], buffer, stack) do
    to_tree(tokens, [{:tag_self_close, name, attrs} | buffer], stack)
  end

  @void_tags ~w(area base br col hr img input link meta param command keygen source)
  defp to_tree([{:tag_open, name, attrs, _meta} | tokens], buffer, stack)
       when name in @void_tags do
    to_tree(tokens, [{:tag_self_close, name, attrs} | buffer], stack)
  end

  defp to_tree([{:tag_open, name, attrs, _meta} | tokens], buffer, stack) do
    to_tree(tokens, [], [{name, attrs, buffer} | stack])
  end

  defp to_tree([{:tag_close, name, _meta} | tokens], buffer, [{name, attrs, upper_buffer} | stack]) do
    tag_block = {:tag_block, name, attrs, Enum.reverse(buffer)}
    to_tree(tokens, [tag_block | upper_buffer], stack)
  end

  # handle eex

  defp to_tree([{:eex, :start_expr, expr, _meta} | tokens], buffer, stack) do
    to_tree(tokens, [], [{:eex_block, expr, buffer} | stack])
  end

  defp to_tree([{:eex, :middle_expr, middle_expr, _meta} | tokens], buffer, [
         {:eex_block, expr, upper_buffer, middle_buffer} | stack
       ]) do
    middle_buffer = [{Enum.reverse(buffer), middle_expr} | middle_buffer]
    to_tree(tokens, [], [{:eex_block, expr, upper_buffer, middle_buffer} | stack])
  end

  defp to_tree([{:eex, :middle_expr, middle_expr, _meta} | tokens], buffer, [
         {:eex_block, expr, upper_buffer} | stack
       ]) do
    middle_buffer = [{Enum.reverse(buffer), middle_expr}]
    to_tree(tokens, [], [{:eex_block, expr, upper_buffer, middle_buffer} | stack])
  end

  defp to_tree([{:eex, :end_expr, end_expr, _meta} | tokens], buffer, [
         {:eex_block, expr, upper_buffer, middle_buffer} | stack
       ]) do
    block = Enum.reverse([{Enum.reverse(buffer), end_expr} | middle_buffer])
    to_tree(tokens, [{:eex_block, expr, block} | upper_buffer], stack)
  end

  defp to_tree([{:eex, :end_expr, end_expr, _meta} | tokens], buffer, [
         {:eex_block, expr, upper_buffer} | stack
       ]) do
    block = [{Enum.reverse(buffer), end_expr}]
    to_tree(tokens, [{:eex_block, expr, block} | upper_buffer], stack)
  end

  defp to_tree([{:eex, _type, expr, meta} | tokens], buffer, stack) do
    to_tree(tokens, [{:eex, expr, meta} | buffer], stack)
  end

  defp count_newlines_until_text(<<char, rest::binary>>, counter) when char in '\s\t\r',
    do: count_newlines_until_text(rest, counter)

  defp count_newlines_until_text(<<?\n, rest::binary>>, counter),
    do: count_newlines_until_text(rest, counter + 1)

  defp count_newlines_until_text(_, counter),
    do: counter

  # LV Tokenizer doesn't tell us when it is an inline comment and we need to know that in order
  # to handle this.
  defp inline_comment?(text) do
    trimmed_text = String.trim(text)
    String.starts_with?(trimmed_text, "<!--") and String.ends_with?(trimmed_text, "-->")
  end
end
