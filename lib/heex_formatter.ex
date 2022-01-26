defmodule HeexFormatter do
  @moduledoc """
  Format Heex templates from `.heex` files or `~H` sigils.

  This is a plugin for Mix format:

  https://hexdocs.pm/mix/main/Mix.Tasks.Format.html#module-plugins

  ### Setup

  add this project as a dependency in your `mix.exs`

  defp deps do
    [
      # ...
      {:heex_formatter, github: "feliperenan/heex_formatter"}
    ]
  end

  Add it as plugin to your project `.formatter` file and make sure to put the
  `heex` extension in the `input` option.

  ```elixir
  [
    plugins: [HeexFormatter],
    inputs: ["*.{heex,ex,exs}", "priv/*/seeds.exs", "{config,lib,test}/**/*.{heex,ex,exs}"],
    # ...
  ]
  ```

  ### options

  * `line_length`: The formatter defaults to a maximum line length of 98 characters,
    which can be overwritten with the `line_length` option in the `.formatter` file.

    Set `heex_line_length` to only set the line:lenght for the heex formatter.

    ```elixir
    [
      # ...omitted
      heex_line_length: 300
    ]
    ```

  ### Formatting

  This formatter tries to be as consistency as possible with the Elixir formatter.
  With that being said, you should expect a similar formatting experience.

  Given a plain HTML like this:

  ```eex
    <section>
    <h1>    Hello</h1>
    </section>
  ```

  Will be formatted as:

  ```eex
  <section>
    <h1>Hello</h1>
  </section>
  ```

  It will break texts to the next line in case there a tag has attributes:

  ```eex
  <section>
    <h1 class="my-class">
      Hello
    </h1>
  </section>
  ```

  And when it is a eex expression:

  ```eex
  <section>
    <h1>
      <%= Hello %>
    </h1>
  </section>
  ```

  Speaking of ieex expressions. Since they are Elixir code, they are formatted
  by Elixir formatter. We just make sure it is well indentend within tags.

  ```eex
  <secion>
    <%= form_for @changeset,
             Routes.user_path(@conn, :create),
             class: "w-full p-3 rounded-md",
             phx_change: "on_change",
             fn f -> %>
      <%= text_input(f, :name) %>
    <% end %>
  </section>
  ```

  It will keep intentional new lines. In fact, the formatter will always keep
  one line in case you have inserted multiple ones:

  ```eex
  <section>


    <h1>
      <%= Hello %>
    </h1>

  </section>
  ```

  Will remove the extra line between `section` and `h1` tag keeping just one.

  ```eex
  <section>

    <h1>
      <%= Hello %>
    </h1>

  </section>
  ```
  """
  @behaviour Mix.Tasks.Format

  alias HeexFormatter.{Formatter, Tokenizer}

  @impl Mix.Tasks.Format
  def features(_opts) do
    [sigils: [:H], extensions: [".heex"]]
  end

  @impl Mix.Tasks.Format
  def format(contents, opts) do
    contents
    |> Tokenizer.tokenize()
    |> Formatter.format(opts)
  end
end
