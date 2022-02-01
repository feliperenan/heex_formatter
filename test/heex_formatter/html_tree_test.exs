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
             {:text, "Text only\n", %{column_end: 1, line_end: 2}},
             {:tag_block, "p", [], %{column: 1, line: 2},
              [
                {:text, "some text", %{column_end: 13, line_end: 2}}
              ]},
             {
               :tag_block,
               "section",
               [],
               %{column: 1, line: 3},
               [
                 {:tag_block, "div", [], %{column: 1, line: 4}, []},
                 {:tag_block, "h1", [], %{column: 1, line: 5},
                  [
                    {:text, "Hello", %{column_end: 10, line_end: 5}}
                  ]}
               ]
             },
             {:tag_block, "h2", [], %{column: 1, line: 6},
              [
                {:text, "Word", %{column_end: 9, line_end: 6}}
              ]}
           ] = HtmlTree.build(tokens)
  end

  test "handle self close tags" do
    contents = """
    <h1>title</p>
    <section>
      <div />
      <p>Hello</p>
    </section>
    """

    tokens = Tokenizer.tokenize(contents)

    assert [
             {:tag_block, "h1", [], %{column: 1, line: 1},
              [
                {:text, "title", %{column_end: 10, line_end: 1}}
              ]},
             {:tag_block, "section", [], %{column: 1, line: 2},
              [
                {:tag_block, "div", [], %{column: 3, line: 3, self_close: true}, []},
                {:tag_block, "p", [], %{column: 3, line: 4},
                 [
                   {:text, "Hello", %{column_end: 11, line_end: 4}}
                 ]}
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
             {:tag_block, "section", [], %{column: 1, line: 1},
              [
                {:tag_block, "p", [], %{column: 3, line: 2},
                 [
                   {:eex_tag, "=", "@user.name", %{block?: false, column: 6, line: 1}}
                 ]}
              ]}
           ] = HtmlTree.build(tokens)
  end

  test "handle eex if/else expressions" do
    contents = """
    <section>
      <p><%= @user.name %></p>
    </section>
    """

    tokens = Tokenizer.tokenize(contents)

    assert [
             {:tag_block, "section", [], %{column: 1, line: 1},
              [
                {:tag_block, "p", [], %{column: 3, line: 2},
                 [
                   {:eex_tag, "=", "@user.name", %{block?: false, column: 6, line: 1}}
                 ]}
              ]}
           ] = HtmlTree.build(tokens)
  end
end
