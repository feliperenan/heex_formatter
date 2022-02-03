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
             {:text, "Text only"},
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
                {:tag_block, "p", [], ["= @user.name"]}
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
             {:eex_block, "= if true do",
              [
                {[{:tag_block, "p", [], [{:text, "test"}]}, "= \"Hello\""], "end"}
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
             {
               :eex_block,
               "= if true do",
               [
                 {[{:tag_block, "p", [], [text: "test"]}, "= \"Hello\""], "else"},
                 {[{:tag_block, "p", [], [text: "error"]}, "= \"World\""], "end"}
               ]
             }
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
             {:eex_block, "= case term do",
              [
                {[], "{:ok, text} ->"},
                {["= text"], "{:error, error} ->"},
                {["= error"], "end"}
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
             {:eex_block, "= cond do",
              [
                {[], "foo? ->"},
                {[{:tag_block, "p", [], [{:text, "foo"}]}], "bar? ->"},
                {[{:tag_block, "p", [], [{:text, "bar"}]}], "true ->"},
                {[{:tag_block, "p", [], [{:text, "baz"}]}], "end"}
              ]}
           ] = HtmlTree.build(tokens)
  end
end
