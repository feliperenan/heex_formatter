# HeexFormatter

[![ElixirCI](https://github.com/feliperenan/heex_formatter/actions/workflows/elixir.yml/badge.svg)](https://github.com/feliperenan/heex_formatter/actions/workflows/elixir.yml)

A code formatter for Heex templates.

:warning: This project is still in alpha stage. There are several cases yet to be handled.

![](examples/example.gif)

### Installation

add `:heex_formatter` as dependency

```elixir
defp deps do
  [
    # ...
    {:heex_formatter, github: "feliperenan/heex_formatter"}
  ]
end
```

Add it as plugin to your project `.formatter` file.

```elixir
[
  plugins: [HeexFormatter],
  import_deps: [:ecto, :phoenix],
  inputs: ["*.{heex,ex,exs}", "priv/*/seeds.exs", "{config,lib,test}/**/*.{heex,ex,exs}"],
  subdirectories: ["priv/*/migrations"]
]
```
Now run
```elixir
mix compile
```

Inspired by [Surface Formatter](https://github.com/surface-ui/surface_formatter).
