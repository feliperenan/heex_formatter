defmodule HeexFormatter.MixProject do
  use Mix.Project

  def project do
    [
      app: :heex_formatter,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Just while this PR gets merged:
      #
      # https://github.com/phoenixframework/phoenix_live_view/pull/1847
      {:phoenix_live_view, github: "phoenixframework/phoenix_live_view"},
      {:jason, "~> 1.3"},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false}
    ]
  end
end
