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

    assert [
             {:text, "Text only\n"},
             {:tag_block, "p", [], [text: "some text"]},
             {:text, "\n"},
             {:tag_block, "section", [],
              [
                {:text, "\n"},
                {:tag_block, "div", [],
                 [
                   {:text, "\n"},
                   {:tag_block, "h1", [], [text: "Hello"]},
                   {:text, "\n"},
                   {:tag_block, "h2", [], [text: "Word"]}
                 ]}
              ]}
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
             {:tag_block, "h1", [], [text: "title"]},
             {:text, "\n"},
             {:tag_block, "section", [],
              [
                {:text, "\n  "},
                {:tag_self_close, "div", []},
                {:text, "\n  "},
                {:tag_block, "p", [], [text: "Hello"]}
              ]}
           ] = HtmlTree.build(tokens)
  end

  test "handle basic eex expressions" do
    contents = """
    <section>
      <p><%= @user.name %></p>
    </section>
    """

    tokens = Tokenizer.tokenize(contents)

    [
      {:tag_block, "section", [],
       [
         {:text, "\n  "},
         {:tag_block, "p", [], [{:eex, "@user.name", %{column: 6, line: 1, opt: '='}}]}
       ]}
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
                {[
                   {:text, "\n  "},
                   {:tag_block, "p", [], [text: "test"]},
                   {:text, "\n  "},
                   {:eex, "\"Hello\"", %{column: 3, line: 2, opt: '='}}
                 ], "end"}
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

    assert [
             {:eex_block, "if true do",
              [
                {[
                   {:text, "\n  "},
                   {:tag_block, "p", [], [text: "test"]},
                   {:text, "\n  "},
                   {:eex, "\"Hello\"", %{column: 3, line: 2, opt: '='}}
                 ], "else"},
                {[
                   {:text, "\n  "},
                   {:tag_block, "p", [], [text: "error"]},
                   {:text, "\n  "},
                   {:eex, "\"World\"", %{column: 3, line: 5, opt: '='}}
                 ], "end"}
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
                {[], "{:ok, text} ->"},
                {[{:text, "\n    "}, {:eex, "text", %{column: 5, line: 2, opt: '='}}],
                 "{:error, error} ->"},
                {[
                   {:text, "\n    "},
                   {:eex, "error", %{column: 5, line: 4, opt: '='}}
                 ], "end"}
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
                {[], "foo? ->"},
                {[{:text, "\n    "}, {:tag_block, "p", [], [text: "foo"]}], "bar? ->"},
                {[{:text, "\n    "}, {:tag_block, "p", [], [text: "bar"]}], "true ->"},
                {[{:text, "\n    "}, {:tag_block, "p", [], [text: "baz"]}], "end"}
              ]}
           ] = HtmlTree.build(tokens)
  end
end
