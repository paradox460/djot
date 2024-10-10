defmodule Djot.MixProject do
  use Mix.Project

  @source_url "https://github.com/paradox460/djot"

  def project do
    [
      app: :djot,
      version: "0.1.2",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      source_url: @source_url,
      homepage_url: @source_url,
      name: "Djot",
      description: "A Djot markup language parser and formatter",
      deps: deps(),
      package: package()
    ]
  end

  def package do
    [
      maintainers: ["Jeff Sandberg"],
      licenses: ["MIT"],
      links: %{
        GitHub: @source_url
      },
      files: ~w[
        lib
        native/djot_nif/src
        native/djot_nif/.cargo
        native/djot_nif/Cargo.*
        mix.exs
        README.md
        LICENSE
      ]
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:rustler, "~> 0.32"},
      {:ex_doc, "~> 0.30.9", only: :dev, runtime: false}
    ]
  end
end
