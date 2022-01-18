defmodule EefTest do
  use ExUnit.Case
  doctest Eef

  # Write a unique file and .formatter.exs for a test, run `mix format` on the
  # file, and assert whether the input matches the expected output.
  defp assert_formatter_output(filename, input_ex, expected, dot_formatter_opts \\ []) do
    ex_path = Path.join(System.tmp_dir(), filename)
    dot_formatter_path = ex_path <> ".formatter.exs"
    dot_formatter_opts = Keyword.put(dot_formatter_opts, :plugins, [Eef])

    on_exit(fn ->
      File.rm(ex_path)
      File.rm(dot_formatter_path)
    end)

    File.write!(ex_path, input_ex)
    File.write!(dot_formatter_path, inspect(dot_formatter_opts))

    Mix.Tasks.Format.run([ex_path, "--dot-formatter", dot_formatter_path])

    assert File.read!(ex_path) == expected
  end

  test "format file indentation" do
    assert_formatter_output(
      "index.html.heex",
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

  @tag :skip
  test "parse eex" do
    html = """
    <section>
      <%= live_redirect to: "url", id: "link", role: "button" do %>
        <div>     content</div>
      <% end %>
    </section>
    """

    assert Eef.format(html, []) == nil
  end
end
