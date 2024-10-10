defmodule Djot.Native do
  version = Mix.Project.config()[:version]
  mode = if Mix.env() in [:dev, :test], do: :debug, else: :release
  github_url = Mix.Project.config()[:package][:links][:GitHub]

  force_build = System.get_env("DJOT_BUILD") in ~w[1 true]  || Mix.env() in [:dev, :test]

  use RustlerPrecompiled,
      otp_app: :djot,
      crate: "djot_nif",
      base_url: "#{github_url}/releases/download/v#{version}",
      force_build: force_build,
      mode: mode,
      targets: Enum.uniq(["aarch64-unknown-linux-musl" | RustlerPrecompiled.Config.default_targets()]),
      version: version

  def to_html(_dj, _options), do: :erlang.nif_error(:nif_not_loaded)
end
