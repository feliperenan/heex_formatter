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
             {:tag_block, "section", [],
              [
                {:tag_block, "div", [],
                 [
                   {:tag_block, "h1", [], [text: "Hello"]},
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
             {:tag_block, "section", [],
              [
                {:tag, "div", []},
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

    assert [
             {:tag_block, "section", [],
              [
                {:tag_block, "p", [],
                 [
                   {:eex_tag, "= @user.name"}
                 ]}
              ]}
           ] = HtmlTree.build(tokens)
  end

  test "handle eex if without else" do
    contents = """
    <%= if true do %>
      <p>test</p>
      <%= "Hello" %>
    <% end %>
    """

    tokens = Tokenizer.tokenize(contents)

    assert [
             {
               :eex_block,
               "= if true do",
               [
                 {[{:tag_block, "p", [], [text: "test"]}, {:eex_tag, "= \"Hello\""}], "end"}
               ]
             }
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
             {:eex_block, "= if true do",
              [
                {[
                   {:tag_block, "p", [], [text: "test"]},
                   {"= \"Hello\"", [{:tag_block, "p", [], [text: "test"]}]}
                 ], "else"},
                {[
                   {:tag_block, "p", [], [text: "error"]},
                   {"= \"World\"", [{:tag_block, "p", [], [text: "error"]}]}
                 ], "end"}
              ]}
           ] = HtmlTree.build(tokens)
  end
end
