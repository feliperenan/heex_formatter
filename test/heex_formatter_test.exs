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

    # Run mix format twice to make sure the formatted file doesn't change after
    # another mix format.
    formatted = run_formatter(ex_path, dot_formatter_path)
    assert formatted == expected
    assert run_formatter(ex_path, dot_formatter_path) == formatted
  end

  def assert_formatter_doesnt_change(code, opts \\ []) do
    assert_formatter_output(code, code, opts)
  end

  defp run_formatter(ex_path, dot_formatter_path) do
    MixFormat.run([ex_path, "--dot-formatter", dot_formatter_path])
    File.read!(ex_path)
  end

  test "always break lines for block elements" do
    input = """
      <section><h1><%= @user.name %></h1></section>
    """

    expected = """
    <section>
      <h1><%= @user.name %></h1>
    </section>
    """

    assert_formatter_output(input, expected)
  end

  test "keep inline elements in the current line" do
    input = """
      <section><h1><b><%= @user.name %></b></h1></section>
    """

    expected = """
    <section>
      <h1><b><%= @user.name %></b></h1>
    </section>
    """

    assert_formatter_output(input, expected)
  end

  test "break inline elements to the next line when it doesn't fit" do
    input = """
      <section><h1><b><%= @user.name %></b></h1></section>
    """

    expected = """
    <section>
      <h1>
        <b>
          <%= @user.name %>
        </b>
      </h1>
    </section>
    """

    assert_formatter_output(input, expected, line_length: 20)
  end

  test "always break line for block elements" do
    input = """
    <h1>1</h1>
    <h2>2</h2>
    <h3>3</h3>
    """

    assert_formatter_doesnt_change(input)
  end

  test "remove unwanted empty lines" do
    input = """
    <section>
    <div>
    <h1>    Hello</h1>
    <h2>
    Sub title
    </h2>
    </div>
    </section>

    """

    expected = """
    <section>
      <div>
        <h1>Hello</h1>
        <h2>
          Sub title
        </h2>
      </div>
    </section>
    """

    assert_formatter_output(input, expected)
  end

  test "texts with inline elements and block elements" do
    input = """
    <div>
      Long long long loooooooooooong text: <i>...</i>.
      <ul>
        <li>Item 1</li>
        <li>Item 2</li>
      </ul>
      Texto
    </div>
    """

    expected = """
    <div>
      Long long long loooooooooooong text:
      <i>...</i>.
      <ul>
        <li>Item 1</li>
        <li>Item 2</li>
      </ul>
      Texto
    </div>
    """

    assert_formatter_output(input, expected, line_length: 20)
  end

  test "add indentation when there aren't any" do
    input = """
    <section>
    <div>
    <h1>Hello</h1>
    </div>
    </section>
    """

    expected = """
    <section>
      <div>
        <h1>Hello</h1>
      </div>
    </section>
    """

    assert_formatter_output(input, expected)
  end

  test "break HTML into multiple lines when it doesn't fit" do
    input = """
    <p class="alert alert-info more-class more-class" role="alert" phx-click="lv:clear-flash" phx-value-key="info">
      <%= live_flash(@flash, :info) %>
    </p>
    """

    expected = """
    <p
      class="alert alert-info more-class more-class"
      role="alert"
      phx-click="lv:clear-flash"
      phx-value-key="info"
    >
      <%= live_flash(@flash, :info) %>
    </p>
    """

    assert_formatter_output(input, expected)
  end

  test "handle HTML attributes" do
    input = """
    <p class="alert alert-info" phx-click="lv:clear-flash" phx-value-key="info">
      <%= live_flash(@flash, :info) %>
    </p>
    """

    assert_formatter_doesnt_change(input)
  end

  test "fix indentation when everything is inline" do
    input = """
    <section><div><h1>Hello</h1></div></section>
    """

    expected = """
    <section>
      <div>
        <h1>Hello</h1>
      </div>
    </section>
    """

    assert_formatter_output(input, expected)
  end

  test "fix indentation when it fits inline" do
    input = """
    <section id="id" phx-hook="PhxHook">
      <.component
        image_url={@url} />
    </section>
    """

    expected = """
    <section id="id" phx-hook="PhxHook">
      <.component image_url={@url} />
    </section>
    """

    assert_formatter_output(input, expected)
  end

  test "keep attributes at the same line if it fits 98 characters (default)" do
    input = """
    <Component foo="..........." bar="..............." baz="............" qux="..................." />
    """

    assert_formatter_doesnt_change(input)
  end

  test "break attributes into multiple lines in case it doesn't fit 98 characters (default)" do
    input = """
    <div foo="..........." bar="....................." baz="................." qux="....................">
    <p><%= @user.name %></p>
    </div>
    """

    expected = """
    <div
      foo="..........."
      bar="....................."
      baz="................."
      qux="...................."
    >
      <p><%= @user.name %></p>
    </div>
    """

    assert_formatter_output(input, expected)
  end

  test "single line inputs are not changed" do
    assert_formatter_doesnt_change("""
    <div />
    """)

    assert_formatter_doesnt_change("""
    <.component with="attribute" />
    """)
  end

  test "handle if/else/end block" do
    input = """
    <%= if true do %>
    <p>do something</p><p>more stuff</p>
    <% else %>
    <p>do something else</p><p>more stuff</p>
    <% end %>
    """

    expected = """
    <%= if true do %>
      <p>do something</p>
      <p>more stuff</p>
    <% else %>
      <p>do something else</p>
      <p>more stuff</p>
    <% end %>
    """

    assert_formatter_output(input, expected)
  end

  test "handle if/end block" do
    input = """
    <%= if true do %><p>do something</p>
    <% end %>
    """

    expected = """
    <%= if true do %>
      <p>do something</p>
    <% end %>
    """

    assert_formatter_output(input, expected)
  end

  test "handle case/end block" do
    input = """
    <div>
    <%= case {:ok, "elixir"} do %>
    <% {:ok, text} -> %>
    <%= text %>
    <p>text</p>
    <div />
    <% {:error, error} -> %>
    <%= error %>
    <p>error</p>
    <div />
    <% end %>
    </div>
    """

    expected = """
    <div>
      <%= case {:ok, "elixir"} do %>
        <% {:ok, text} -> %>
          <%= text %>
          <p>text</p>
          <div />
        <% {:error, error} -> %>
          <%= error %>
          <p>error</p>
          <div />
      <% end %>
    </div>
    """

    assert_formatter_output(input, expected)
  end

  test "format when there are EEx tags" do
    input = """
      <section>
        <%= live_redirect to: "url", id: "link", role: "button" do %>
          <div>     <p>content 1</p><p>content 2</p></div>
        <% end %>
        <p><%= @user.name %></p>
        <%= if true do %> <p>deu bom</p><% else %><p> deu ruim </p><% end %>
      </section>
    """

    expected = """
    <section>
      <%= live_redirect to: "url", id: "link", role: "button" do %>
        <div>
          <p>content 1</p>
          <p>content 2</p>
        </div>
      <% end %>
      <p><%= @user.name %></p>
      <%= if true do %>
        <p>deu bom</p>
      <% else %>
        <p>deu ruim</p>
      <% end %>
    </section>
    """

    assert_formatter_output(input, expected)
  end

  test "does not add newline after DOCTYPE" do
    input = """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
      </head>
      <body>
        <%= @inner_content %>
      </body>
    </html>
    """

    assert_formatter_doesnt_change(input)
  end

  test "format tags with attributes without value" do
    assert_formatter_output(
      """

        <button class="btn-primary" autofocus disabled> Submit </button>

      """,
      """
      <button class="btn-primary" autofocus disabled>Submit</button>
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
      <p>
        $<%= @product.value %>in Dollars
      </p>
      <button>
        Submit
      </button>
      """
    )
  end

  test "parse eex inside of html tags" do
    assert_formatter_output(
      """
        <button {build_phx_attrs_dynamically()}>Test</button>
      """,
      """
      <button {build_phx_attrs_dynamically()}>Test</button>
      """
    )
  end

  test "format long lines splitting into multiple lines" do
    assert_formatter_output(
      """
        <p><span>this is a long long long long long looooooong text</span><%= @product.value %> and more stuff over here</p>
      """,
      """
      <p>
        <span>this is a long long long long long looooooong text</span><%= @product.value %>
        and more stuff over here
      </p>
      """
    )
  end

  test "handle eex cond statement" do
    input = """
    <div>
    <%= cond do %>
    <% 1 == 1 -> %>
    <%= "Hello" %>
    <% 2 == 2 -> %>
    <%= "World" %>
    <% true -> %>
    <%= "" %>
    <% end %>
    </div>
    """

    expected = """
    <div>
      <%= cond do %>
        <% 1 == 1 -> %>
          <%= "Hello" %>
        <% 2 == 2 -> %>
          <%= "World" %>
        <% true -> %>
          <%= "" %>
      <% end %>
    </div>
    """

    assert_formatter_output(input, expected)
  end

  test "proper format elixir functions" do
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

  test "does not add parentheses when tag is configured to not to" do
    input = """
    <%= text_input f, :name %>
    """

    expected = """
    <%= text_input f, :name %>
    """

    assert_formatter_output(input, expected, locals_without_parens: [text_input: 2])
  end

  test "does not add a line break in the first line" do
    assert_formatter_output(
      """
      <%= @user.name %>
      """,
      """
      <%= @user.name %>
      """
    )

    assert_formatter_output(
      """
      <div />
      """,
      """
      <div />
      """
    )

    assert_formatter_output(
      """
      <% "Hello" %>
      """,
      """
      <% "Hello" %>
      """
    )
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
    <p>
      My title
    </p>
    <p>
      This is tooooooooooooooooooooooooooooooooooooooo looooooong annnnnnnnnnnnnnd should breeeeeak liines
    </p>
    <p class="some-class">Should break line</p>
    <p><%= @user.name %></p>
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

  test "handle case statement within for statement" do
    input = """
    <tr>
      <%= for value <- @values do %>
        <td class="border-2">
          <%= case value.type do %>
          <% :text -> %>
          Do something
          <p>Hello</p>
          <% _ -> %>
          Do something else
          <p>Hello</p>
          <% end %>
        </td>
      <% end %>
    </tr>
    """

    expected = """
    <tr>
      <%= for value <- @values do %>
        <td class="border-2">
          <%= case value.type do %>
            <% :text -> %>
              Do something
              <p>Hello</p>
            <% _ -> %>
              Do something else
              <p>Hello</p>
          <% end %>
        </td>
      <% end %>
    </tr>
    """

    assert_formatter_output(input, expected)
  end

  test "proper indent if when it is in the beginning of the template" do
    input = """
    <%= if @live_action == :edit do %>
    <.modal return_to={Routes.store_index_path(@socket, :index)}>
      <.live_component
        id={@product.id}
        module={MystoreWeb.ReserveFormComponent}
        action={@live_action}
        product={@product}
        return_to={Routes.store_index_path(@socket, :index)}
      />
    </.modal>
    <% end %>
    """

    expected = """
    <%= if @live_action == :edit do %>
      <.modal return_to={Routes.store_index_path(@socket, :index)}>
        <.live_component
          id={@product.id}
          module={MystoreWeb.ReserveFormComponent}
          action={@live_action}
          product={@product}
          return_to={Routes.store_index_path(@socket, :index)}
         />
      </.modal>
    <% end %>
    """

    assert_formatter_output(input, expected)
  end

  test "handle void elements" do
    input = """
    <div>
    <link rel="shortcut icon" href={Routes.static_path(@conn, "/images/favicon.png")} type="image/x-icon">
    <p>some text</p>
    <br>
    <hr>
    <input type="text" value="Foo Bar">
    <img src="./image.png">
    </div>
    """

    expected = """
    <div>
      <link
        rel="shortcut icon"
        href={Routes.static_path(@conn, "/images/favicon.png")}
        type="image/x-icon"
       />
      <p>some text</p>
      <br />
      <hr />
      <input type="text" value="Foo Bar" />
      <img src="./image.png" />
    </div>
    """

    assert_formatter_output(input, expected)
  end

  test "format expressions within attributes" do
    input = """
      <.modal
        id={id}
        on_cancel={focus("#1", "#delete-song-1")}
        on_confirm={JS.push("delete", value: %{id: song.id})
                    |> hide_modal(id)
                    |> focus_closest("#song-1")
                    |> hide("#song-1")}
      />
    """

    expected = """
    <.modal
      id={id}
      on_cancel={focus("#1", "#delete-song-1")}
      on_confirm={
        JS.push("delete", value: %{id: song.id})
        |> hide_modal(id)
        |> focus_closest("#song-1")
        |> hide("#song-1")
      }
     />
    """

    assert_formatter_output(input, expected)
  end

  test "keep intentional line breaks" do
    input = """
    <section>
      <h1>
        <b>
          <%= @user.first_name %><%= @user.last_name %>
        </b>
      </h1>

      <div>
        <p>test</p>
      </div>

      <h2>Subtitle</h2>
    </section>
    """

    assert_formatter_doesnt_change(input)
  end

  test "keep eex expressions in the next line" do
    input = """
    <div class="mb-5">
      <%= live_file_input(@uploads.image_url) %>
      <%= error_tag(f, :image_url) %>
    </div>
    """

    assert_formatter_doesnt_change(input)
  end

  test "keep intentional extra line break between eex expressions" do
    input = """
    <div class="mb-5">
      <%= live_file_input(@uploads.image_url) %>

      <%= error_tag(f, :image_url) %>
    </div>
    """

    assert_formatter_doesnt_change(input)
  end

  test "force unfit when there are line breaks in the text" do
    assert_formatter_doesnt_change("""
    <b>
      Text
      Text
      Text
    </b>
    <p>
      Text
      Text
      Text
    </p>
    """)

    assert_formatter_output(
      """
      <b>\s\s
      \tText
        Text
      \tText
      </b>
      """,
      """
      <b>
        Text
        Text
        Text
      </b>
      """
    )

    assert_formatter_output(
      """
      <b>\s\s
      \tText
      \t
      \tText
      </b>
      """,
      """
      <b>
        Text

        Text
      </b>
      """
    )

    assert_formatter_output(
      """
      <b>\s\s
      \t
      \tText
      \t
      \t
      \tText
      \t
      </b>
      """,
      """
      <b>
        Text

        Text
      </b>
      """
    )
  end

  test "doesn't format content within <pre>" do
    assert_formatter_output(
      """
      <div>
      <pre>
      Text
      Text
      </pre>
      </div>
      """,
      """
      <div>
        <pre>
      Text
      Text
        </pre>
      </div>
      """
    )

    assert_formatter_doesnt_change("""
    <pre>
    Text
      <div>Text</div>
    </pre>
    """)

    assert_formatter_doesnt_change("""
    <pre><code><div>
    <p>Text</p>
    <%= if true do %>
      Hi
    <% else %>
      Ho
    <% end %>
    <p>Text</p>
    </div></code></pre>
    """)
  end

  # test "handle code tags but don't touch the code inside" do
  #   input = """
  #   <div>
  #   <code>
  #   public static void main(String[] args) {
  #     System.out.println("Moin")
  #   }
  #   </code>
  #   </div>
  #   """

  #   expected = """
  #   <div>
  #     <code>
  #   public static void main(String[] args) {
  #     System.out.println("Moin")
  #   }
  #     </code>
  #   </div>
  #   """

  #   assert_formatter_output(input, expected)
  # end

  # test "formats script tag" do
  #   input = """
  #   <body>

  #   text
  #     <div><script>
  #       var foo = 1;
  #       console.log(foo);
  #     </script></div>

  #   </body>
  #   """

  #   expected = """
  #   <body>
  #     <div>
  #       <script>
  #         var foo = 1;
  #         console.log(foo);
  #       </script>
  #     </div>
  #   </body>
  #   """

  #   assert_formatter_output(input, expected)
  # end

  # test "handle HTML comments but doens't format it" do
  #   input = """
  #       <!-- Inline comment -->
  #   <section>
  #     <!-- commenting out this div
  #     <div>
  #       <p><%= @user.name %></p>
  #       <p
  #         class="my-class">
  #         text
  #       </p>
  #     </div>
  #        -->
  #   </section>
  #   """

  #   expected = """
  #       <!-- Inline comment -->
  #   <section>
  #     <!-- commenting out this div
  #     <div>
  #       <p><%= @user.name %></p>
  #       <p
  #         class="my-class">
  #         text
  #       </p>
  #     </div>
  #        -->
  #   </section>
  #   """

  #   assert_formatter_output(input, expected)
  # end

  # test "handle multiple comments in a row" do
  #   input = """
  #   <div><p>Hello</p></div>
  #         <!-- <%= 1 %> --><!-- <%= 2 %> -->
  #         <div><p>Hello</p></div>
  #   """

  #   expected = """
  #   <div>
  #     <p>Hello</p>
  #   </div>
  #         <!-- <%= 1 %> --><!-- <%= 2 %> -->
  #   <div>
  #     <p>Hello</p>
  #   </div>
  #   """

  #   assert_formatter_output(input, expected)
  # end

  # test "put eex in the next line when it comes right after a HTML comment" do
  #   input = """
  #   <!-- Modal content -->
  #   <%= render_slot(@inner_block) %>
  #   """

  #   expected = """
  #   <!-- Modal content -->
  #   <%= render_slot(@inner_block) %>
  #   """

  #   assert_formatter_output(input, expected)
  # end

  # test "keep single line breaks" do
  #   input = """
  #   <div>
  #   <h2><%= @title %></h2>

  #   <.form id="user-form" let={f} for={@changeset} phx-submit="save" >
  #     <%= text_input f, :name %>
  #     <%= error_tag(f, :name) %>

  #     <%= number_input(f, :age) %>
  #     <%= error_tag(f, :age) %>

  #     <%= submit("Save", phx_disable_with: "Saving...") %>
  #   </.form>
  #   </div>
  #   """

  #   expected = """
  #   <div>
  #     <h2>
  #       <%= @title %>
  #     </h2>

  #     <.form id="user-form" let={f} for={@changeset} phx-submit="save">
  #       <%= text_input(f, :name) %>
  #       <%= error_tag(f, :name) %>

  #       <%= number_input(f, :age) %>
  #       <%= error_tag(f, :age) %>

  #       <%= submit("Save", phx_disable_with: "Saving...") %>
  #     </.form>
  #   </div>
  #   """

  #   assert_formatter_output(input, expected)
  # end

  # test "format label block correctly" do
  #   input = """
  #   <%= label @f, :email_address, class: "text-gray font-medium" do %> Email Address
  #   <% end %>
  #   """

  #   expected = """
  #   <%= label @f, :email_address, class: "text-gray font-medium" do %>
  #     Email Address
  #   <% end %>
  #   """

  #   assert_formatter_output(input, expected)
  # end

  #
  # test "handle script tags but don't touch JS code" do
  #   input = """
  #   <div>
  #   <script>
  #   function my_confirm(event) {
  #     if (!confirm('<%= "confirmation text" %>')) {
  #     event.stopPropagation()
  #   }
  #     return false;
  #   };
  #   </script>
  #   <script>
  #   function my_confirm(event) {
  #     if (!confirm('foo')) { event.stopPropagation() }
  #     return false;
  #   };
  #   </script>
  #   </div>
  #   """

  #   expected = """
  #   <div>
  #     <script>
  #   function my_confirm(event) {
  #     if (!confirm('<%= "confirmation text" %>')) {
  #     event.stopPropagation()
  #   }
  #     return false;
  #   };
  #     </script>
  #     <script>
  #   function my_confirm(event) {
  #     if (!confirm('foo')) { event.stopPropagation() }
  #     return false;
  #   };
  #     </script>
  #   </div>
  #   """

  #   assert_formatter_output(input, expected)
  # end
  #
  # test "handle style tags but don't touch CSS code" do
  #   input = """
  #   <div>
  #   <style>
  #   h1 {
  #     font-weight: 900;
  #   }
  #   </style>
  #   </div>
  #   """

  #   expected = """
  #   <div>
  #     <style>
  #   h1 {
  #     font-weight: 900;
  #   }
  #     </style>
  #   </div>
  #   """

  #   assert_formatter_output(input, expected)
  # end
end
