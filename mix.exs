defmodule RustyOpus.MixProject do
  use Mix.Project

  @version "0.4.0"
  @source_url "https://github.com/mindreframer/rusty_opus"

  def project do
    [
      app: :rusty_opus,
      version: @version,
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      description:
        "Pure-Rust in-process WAV, MP3, and Ogg Opus conversion for Elixir via Rustler",
      source_ref: "v#{@version}",
      source_url: @source_url,
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:rustler, "== 0.36.2", runtime: false},
      {:rustler_precompiled, "~> 0.9"},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "docs/installation.md",
        "docs/codec.md",
        "docs/quality.md",
        "docs/qualification.md",
        "docs/provenance.md",
        "docs/troubleshooting.md",
        "SECURITY.md",
        "CHANGELOG.md"
      ],
      groups_for_extras: [
        Codec: ~r/docs\/(codec|quality)\.md/,
        Operations: ~r/docs\/(installation|troubleshooting)\.md/,
        "Project information": ~r/(provenance|qualification)\.md|SECURITY\.md|CHANGELOG\.md/
      ]
    ]
  end

  defp package do
    [
      maintainers: ["Roman Heinrich"],
      licenses: ["Apache-2.0"],
      links: %{"Source" => @source_url, "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"},
      exclude_patterns: ["/target/"],
      files:
        ~w(lib native/rusty_opus_native/src native/rusty_opus_native/Cargo.toml
           native/rusty_opus_native/Cargo.lock native/rusty_opus_native/build.rs
           test/fixtures/manifest.json
           native/rusty_opus_native/rust-toolchain.toml docs LICENSE NOTICE
           CHANGELOG.md SECURITY.md README.md mix.exs .formatter.exs) ++
          Path.wildcard("checksum-*.exs")
    ]
  end
end
