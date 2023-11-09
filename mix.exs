defmodule Djot.MixProject do
  use Mix.Project

  @source_url "https://github.com/paradox460/djot"

  def project do
    [
      app: :djot,
      version: "2023.11.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      source_url: @source_url,
      homepage_url: @source_url,
      name: "Djot",
      description: "A Djot parser and formatter",
      deps: deps()
    ]
  end

  def package do
    [
      maintainers: ["Jeff Sandberg"],
      licenses: ["MIT"],
      links: %{
        GitHub: @source_url
      }
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:rustler, "~> 0.30.0"}
    ]
  end
end
