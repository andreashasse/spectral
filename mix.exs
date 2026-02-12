defmodule Spectral.MixProject do
  use Mix.Project

  def project do
    [
      app: :spectral,
      version: "0.4.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      docs: docs(),
      name: "Spectral",
      source_url: "https://github.com/andreashasse/spectral",
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # Temporary git-branch dependency for JSON Schema/OpenAPI documentation support.
      # TODO: Replace with a released :spectra version from Hex (or a tagged release)
      # once the required functionality is available upstream.
      {:spectra, github: "andreashasse/spectra", branch: "json-schema-doc-support"},
      # Code quality tools
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.7", only: [:dev], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp description() do
    """
    Spectral provides type-driven JSON encoding/decoding, JSON Schema generation, and OpenAPI 3.0
    specification generation. It uses Elixir's type system to automatically handle serialization
    based on struct type definitions.
    """
  end

  defp package() do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/andreashasse/spectral"},
      files: ~w(lib .formatter.exs mix.exs README.md CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      filter_modules: fn module, _metadata ->
        module not in [
          Person,
          Person.Address,
          MultiTypeModule,
          MultiTypeModuleReversed,
          MultiTypeModuleFirstMissing,
          SemanticPairingTestModule,
          TypeWithParams
        ]
      end
    ]
  end
end
