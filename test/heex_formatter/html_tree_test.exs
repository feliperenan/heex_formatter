defmodule HeexFormatter.HtmlTreeTest do
  use ExUnit.Case

  alias HeexFormatter.{HtmlTree, Tokenizer}

  doctest HeexFormatter.HtmlTree

  test "build an HTML tree from the given tokens" do
    contents = """
    Text only
    <p>some text</p>
    <section>
    <div>
    <h1>Hello</h1>
    <h2>Word</h2>
    </div>
    </section>
    """

    tokens = Tokenizer.tokenize(contents)

    [
      {:text, "Text only\n", %{newlines: 0}},
      {:tag_block, "p", [], [{:text, "some text", %{newlines: 0}}], %{force_newline?: false}},
      {:text, "\n", %{newlines: 1}},
      {:tag_block, "section", [],
       [
         {:tag_block, "div", [],
          [
            {:tag_block, "h1", [], [{:text, "Hello", %{newlines: 0}}], %{force_newline?: false}},
            {:text, "\n", %{newlines: 1}},
            {:tag_block, "h2", [], [{:text, "Word", %{newlines: 0}}], %{force_newline?: false}}
          ], %{force_newline?: true}}
       ], %{force_newline?: true}}
    ] = HtmlTree.build(tokens)
  end

  test "handle self close tags" do
    contents = """
    <h1>title</h1>
    <section>
      <div />
      <p>Hello</p>
    </section>
    """

    tokens = Tokenizer.tokenize(contents)

    assert [
             {:tag_block, "h1", [], [{:text, "title", %{newlines: 0}}], %{force_newline?: false}},
             {:text, "\n", %{newlines: 1}},
             {:tag_block, "section", [],
              [
                {:tag_self_close, "div", []},
                {:text, "\n  ", %{newlines: 1}},
                {:tag_block, "p", [], [{:text, "Hello", %{newlines: 0}}],
                 %{force_newline?: false}}
              ], %{force_newline?: true}}
           ] = HtmlTree.build(tokens)
  end

  test "handle basic eex expressions" do
    contents = """
    <section>
      <p><%= @user.name %></p>
    </section>
    """

    tokens = Tokenizer.tokenize(contents)

    assert [
             {:tag_block, "section", [],
              [
                {:tag_block, "p", [],
                 [
                   {:eex, "@user.name", %{column: 6, line: 1, opt: '='}}
                 ], %{force_newline?: false}}
              ], %{force_newline?: true}}
           ] = HtmlTree.build(tokens)
  end

  test "handle if without else" do
    contents = """
    <%= if true do %>
      <p>test</p>
      <%= "Hello" %>
    <% end %>
    """

    tokens = Tokenizer.tokenize(contents)

    assert [
             {:eex_block, "if true do",
              [
                {
                  [
                    {:tag_block, "p", [], [{:text, "test", %{newlines: 0}}],
                     %{force_newline?: false}},
                    {:text, "\n  ", %{newlines: 1}},
                    {:eex, "\"Hello\"", %{column: 3, line: 2, opt: '='}}
                  ],
                  "end",
                  %{force_newline?: true}
                }
              ]}
           ] = HtmlTree.build(tokens)
  end

  test "handle eex if/else expressions" do
    contents = """
    <%= if true do %>
      <p>test</p>
      <%= "Hello" %>
    <% else %>
      <p>error</p>
      <%= "World" %>
    <% end %>
    """

    tokens = Tokenizer.tokenize(contents)

    [
      {:eex_block, "if true do",
       [
         {
           [
             {:tag_block, "p", [], [{:text, "test", %{newlines: 0}}], %{force_newline?: false}},
             {:text, "\n  ", %{newlines: 1}},
             {:eex, "\"Hello\"", %{column: 3, line: 2, opt: '='}}
           ],
           "else",
           %{force_newline?: true}
         },
         {
           [
             {:tag_block, "p", [], [{:text, "error", %{newlines: 0}}], %{force_newline?: false}},
             {:text, "\n  ", %{newlines: 1}},
             {:eex, "\"World\"", %{column: 3, line: 5, opt: '='}}
           ],
           "end",
           %{force_newline?: true}
         }
       ]}
    ] = HtmlTree.build(tokens)
  end

  test "handle case expressions" do
    contents = """
    <%= case term do %>
      <% {:ok, text} -> %>
        <%= text %>
      <% {:error, error} -> %>
        <%= error %>
    <% end %>
    """

    tokens = Tokenizer.tokenize(contents)

    assert [
             {:eex_block, "case term do",
              [
                {[], "{:ok, text} ->", %{force_newline?: false}},
                {
                  [{:eex, "text", %{column: 5, line: 2, opt: '='}}],
                  "{:error, error} ->",
                  %{force_newline?: true}
                },
                {
                  [{:eex, "error", %{column: 5, line: 4, opt: '='}}],
                  "end",
                  %{force_newline?: true}
                }
              ]}
           ] = HtmlTree.build(tokens)
  end

  test "handle cond statement" do
    contents = """
    <%= cond do %>
      <% foo? -> %>
        <p>foo</p>
      <% bar? -> %>
        <p>bar</p>
      <% true -> %>
        <p>baz</p>
    <% end %>
    """

    tokens = Tokenizer.tokenize(contents)

    assert [
             {:eex_block, "cond do",
              [
                {[], "foo? ->", %{force_newline?: false}},
                {
                  [
                    {:tag_block, "p", [], [{:text, "foo", %{newlines: 0}}],
                     %{force_newline?: false}}
                  ],
                  "bar? ->",
                  %{force_newline?: true}
                },
                {
                  [
                    {:tag_block, "p", [], [{:text, "bar", %{newlines: 0}}],
                     %{force_newline?: false}}
                  ],
                  "true ->",
                  %{force_newline?: true}
                },
                {
                  [
                    {:tag_block, "p", [], [{:text, "baz", %{newlines: 0}}],
                     %{force_newline?: false}}
                  ],
                  "end",
                  %{force_newline?: true}
                }
              ]}
           ] = HtmlTree.build(tokens)
  end
end
