defmodule Djot.MixProject do
  use Mix.Project

  @source_url "https://github.com/paradox460/djot"
  @version "0.1.5"
  @dev? String.ends_with?(@version, "-dev")
  @force_build? System.get_env("DJOT_BUILD") in ~w[1 true]

  def project do
    [
      app: :djot,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      source_url: @source_url,
      homepage_url: @source_url,
      name: "Djot",
      description: "A Djot markup language parser and formatter",
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  def package do
    [
      maintainers: ["Jeff Sandberg"],
      licenses: ["MIT"],
      links: %{
        GitHub: @source_url,
        Djot: "https://djot.net"
      },
      files: ~w[
        lib
        native/djot_nif/src
        native/djot_nif/.cargo
        native/djot_nif/Cargo.*
        checksum-*.exs
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
      {:rustler, "~> 0.38", optional: not (@dev? or @force_build?)},
      {:rustler_precompiled, "~> 0.9"},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end
end
