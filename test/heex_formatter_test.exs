defmodule HeexFormatterTest do
  use ExUnit.Case
  doctest HeexFormatter

  alias Mix.Tasks.Format, as: MixFormat

  # Write a unique file and .formatter.exs for a test, run `mix format` on the
  # file, and assert whether the input matches the expected output.
  defp assert_formatter_output(input_ex, expected, dot_formatter_opts \\ []) do
    filename = "index.html.heex"
    ex_path = Path.join(System.tmp_dir(), filename)
    dot_formatter_path = ex_path <> ".formatter.exs"
    dot_formatter_opts = Keyword.put(dot_formatter_opts, :plugins, [HeexFormatter])

    on_exit(fn ->
      File.rm(ex_path)
      File.rm(dot_formatter_path)
    end)

    File.write!(ex_path, input_ex)
    File.write!(dot_formatter_path, inspect(dot_formatter_opts))

    MixFormat.run([ex_path, "--dot-formatter", dot_formatter_path])

    assert File.read!(ex_path) == expected
  end

  def assert_formatter_doesnt_change(code, opts \\ []) do
    assert_formatter_output(code, code, opts)
  end

  test "remove unwanted empty lines" do
    assert_formatter_output(
      """


      <section>



      <div>
      <h1>    Hello</h1>
      <h2>


      Sub title

      </h2>



      </div>
      </section>

      """,
      """
      <section>
        <div>
          <h1>Hello</h1>
          <h2>Sub title</h2>
        </div>
      </section>
      """
    )
  end

  test "add indentation when there aren't any" do
    assert_formatter_output(
      """
      <section>
      <div>
      <h1>Hello</h1>
      </div>
      </section>
      """,
      """
      <section>
        <div>
          <h1>Hello</h1>
        </div>
      </section>
      """
    )
  end

  test "fix indentation when it fits inline" do
    assert_formatter_output(
      """
      <section id="id" phx-hook="PhxHook">
        <.component
          image_url={@url} />
      </section>
      """,
      """
      <section id="id" phx-hook="PhxHook">
        <.component image_url={@url} />
      </section>
      """
    )
  end

  test "format inline HTML indentation" do
    assert_formatter_output(
      """
      <section><div><h1>Hello</h1></div></section>
      """,
      """
      <section>
        <div>
          <h1>Hello</h1>
        </div>
      </section>
      """
    )
  end

  test "attributes wrap after 98 characters by default" do
    assert_formatter_doesnt_change("""
    <Component foo="..........." bar="..............." baz="............" qux="..................." />
    """)

    assert_formatter_output(
      """
      <Component foo="..........." bar="..............." baz="............" qux="...................." />
      """,
      """
      <Component
        foo="..........."
        bar="..............."
        baz="............"
        qux="...................."
      />
      """
    )

    assert_formatter_output(
      """
      <Component
          foo={MyappWeb.User.FormComponent}
        bar="..............."
        baz="............"
                  qux="...................."
      />
      """,
      """
      <Component
        foo={MyappWeb.User.FormComponent}
        bar="..............."
        baz="............"
        qux="...................."
      />
      """
    )

    assert_formatter_output(
      """
      <div foo="..........." bar="..............." baz="............" qux="...................." bla="......">
        <h1>Title</h1>
      </div>
      """,
      """
      <div
        foo="..........."
        bar="..............."
        baz="............"
        qux="...................."
        bla="......"
      >
        <h1>Title</h1>
      </div>
      """
    )
  end

  test "make the line_length configurable" do
    assert_formatter_doesnt_change("""
    <Component foo="..........." bar="..............." baz="............" qux="..................." />
    """)

    assert_formatter_output(
      """
      <Component foo="..........." bar="..............." baz="............" qux="..................." />
      """,
      """
      <Component
        foo="..........."
        bar="..............."
        baz="............"
        qux="..................."
      />
      """,
      line_length: 20
    )

    assert_formatter_output(
      """
      <Component foo="..........." bar="..............." baz="............" qux="..................." />
      """,
      """
      <Component
        foo="..........."
        bar="..............."
        baz="............"
        qux="..................."
      />
      """,
      heex_line_length: 20,
      line_length: 2000
    )
  end

  test "single line inputs are not changed" do
    assert_formatter_doesnt_change("""
    <div />
    """)

    assert_formatter_doesnt_change("""
    <.component with="attribute" />
    """)
  end

  test "format when there are EEx tags" do
    assert_formatter_output(
      """
      <section>
        <%= live_redirect to: "url", id: "link", role: "button" do %>
          <div>     <p>content 1</p><p>content 2</p></div>
        <% end %>
        <p>
        <%=
        user.name
        %></p>
        <%= if true do %> <p>deu bom</p><% else %><p> deu ruim </p><% end %>
      </section>
      """,
      """
      <section>
        <%= live_redirect to: "url", id: "link", role: "button" do %>
          <div>
            <p>content 1</p>
            <p>content 2</p>
          </div>
        <% end %>
        <p>
          <%= user.name %>
        </p>
        <%= if true do %>
          <p>deu bom</p>
        <% else %>
          <p>deu ruim</p>
        <% end %>
      </section>
      """
    )
  end

  test "format tags with attributes without value" do
    assert_formatter_output(
      """

        <button class="btn-primary" autofocus disabled> Submit </button>

      """,
      """
      <button class="btn-primary" autofocus disabled>
        Submit
      </button>
      """
    )
  end

  test "keep tags with text and eex expressions inline" do
    assert_formatter_output(
      """
        <p>
          $
          <%= @product.value %> in Dollars
        </p>

        <button>
          Submit
        </button>
      """,
      """
      <p>$ <%= @product.value %> in Dollars</p>
      <button>Submit</button>
      """
    )
  end

  test "parse eex inside of html tags" do
    assert_formatter_output(
      """
        <button {build_phx_attrs_dynamically()}>Test</button>
      """,
      """
      <button {build_phx_attrs_dynamically()}>
        Test
      </button>
      """
    )
  end

  test "format long lines to be split into multiple lines" do
    assert_formatter_output(
      """
        <p><span>this is a long long long long long looooooong text</span><%= @product.value %> and more stuff over here</p>
      """,
      """
      <p>
        <span>this is a long long long long long looooooong text</span>
        <%= @product.value %> and more stuff over here
      </p>
      """
    )
  end

  test "handle eex case statement" do
    input = """
    <div>
    <%= case {:ok, "elixir"} do %>
    <% {:ok, text} -> %>
    <%= text %>

    <% {:error, error} -> %>
    <%= error %>
    <% end %>
    </div>
    """

    expected = """
    <div>
      <%= case {:ok, "elixir"} do %>
      <% {:ok, text} -> %>
        <%= text %>
      <% {:error, error} -> %>
        <%= error %>
      <% end %>
    </div>
    """

    assert_formatter_output(input, expected)
  end

  test "handle script tags but don't touch JS code" do
    input = """
    <div>
    <script>
    function my_confirm(event) {
      if (!confirm(' <%= "confirmation text" %> ')) {
      event.stopPropagation()
    }
      return false;
    };
    </script>
    <script>
    function my_confirm(event) {
      if (!confirm('foo')) { event.stopPropagation() }
      return false;
    };
    </script>
    </div>
    """

    expected = """
    <div>
      <script>
    function my_confirm(event) {
      if (!confirm(' <%= "confirmation text" %> ')) {
      event.stopPropagation()
    }
      return false;
    };
      </script>
      <script>
    function my_confirm(event) {
      if (!confirm('foo')) { event.stopPropagation() }
      return false;
    };
      </script>
    </div>
    """

    assert_formatter_output(input, expected)
  end

  test "handle style tags but don't touch CSS code" do
    input = """
    <div>
    <style>
    h1 {
      font-weight: 900;
    }
    </style>
    </div>
    """

    expected = """
    <div>
      <style>
    h1 {
      font-weight: 900;
    }
      </style>
    </div>
    """

    assert_formatter_output(input, expected)
  end

  test "handle pre tags but don't touch the preformatted contents" do
    input = """
    <div>
    <pre>
    break
       break
    </pre>
    </div>
    """

    expected = """
    <div>
      <pre>
    break
       break
      </pre>
    </div>
    """

    assert_formatter_output(input, expected)
  end

  test "handle code tags but don't touch the code inside" do
    input = """
    <div>
    <code>
    public static void main(String[] args) {
      System.out.println("Moin")
    }
    </code>
    </div>
    """

    expected = """
    <div>
      <code>
    public static void main(String[] args) {
      System.out.println("Moin")
    }
      </code>
    </div>
    """

    assert_formatter_output(input, expected)
  end

  test "handle live_component format" do
    input = """
    <div>
    <%= live_component(MyAppWeb.Components.SearchBox, id: :search_box, on_select: :user_selected, label: gettext("Search User")) %>
    </div>
    """

    expected = """
    <div>
      <%= live_component(MyAppWeb.Components.SearchBox,
        id: :search_box,
        on_select: :user_selected,
        label: gettext("Search User")
      ) %>
    </div>
    """

    assert_formatter_output(input, expected)
  end

  test "handle eex form format" do
    input = """
    <div>
    <%= form_for @changeset, Routes.user_path(@conn, :create), [class: "w-full p-3 rounded-md", phx_change: "on_change"], fn f -> %>
      <%= text_input f, :name %>
    <% end %>
    </div>
    """

    expected = """
    <div>
      <%= form_for @changeset,
               Routes.user_path(@conn, :create),
               [class: "w-full p-3 rounded-md", phx_change: "on_change"],
               fn f -> %>
        <%= text_input(f, :name) %>
      <% end %>
    </div>
    """

    assert_formatter_output(input, expected)
  end

  test "does not add parentheses when tag is configured to not to" do
    input = """
    <%= text_input f, :name %>
    """

    expected = """
    <%= text_input f, :name %>
    """

    assert_formatter_output(input, expected, locals_without_parens: [text_input: 2])
  end

  test "use the configured line_length for breaking texts into new lines" do
    input = """
      <p>My title</p>
    """

    expected = """
    <p>
      My title
    </p>
    """

    assert_formatter_output(input, expected, line_length: 5)
  end

  test "doesn't break lines when tag doesn't have any attrs and it fits using the configured line length" do
    input = """
      <p>
      My title
      </p>
      <p>This is tooooooooooooooooooooooooooooooooooooooo looooooong annnnnnnnnnnnnnd should breeeeeak liines</p>
      <p class="some-class">Should break line</p>
      <p><%= @user.name %></p>
      should not break when there it is not wrapped by any tags
    """

    expected = """
    <p>My title</p>
    <p>
      This is tooooooooooooooooooooooooooooooooooooooo looooooong annnnnnnnnnnnnnd should breeeeeak liines
    </p>
    <p class="some-class">
      Should break line
    </p>
    <p>
      <%= @user.name %>
    </p>
    should not break when there it is not wrapped by any tags
    """

    assert_formatter_output(input, expected)
  end

  test "does not break lines when tag doesn't contain content" do
    input = """
    <thead>
      <tr>
        <th>Name</th>
        <th>Age</th>

        <th></th>
        <th>
        </th>
      </tr>
    </thead>
    """

    expected = """
    <thead>
      <tr>
        <th>Name</th>
        <th>Age</th>
        <th></th>
        <th></th>
      </tr>
    </thead>
    """

    assert_formatter_output(input, expected)
  end
end
