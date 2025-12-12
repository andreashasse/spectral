defmodule Spectral.MixProject do
  use Mix.Project

  def project do
    [
      app: :spectral,
      version: "0.1.2",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      docs: docs(),
      name: "Spectral",
      source_url: "https://github.com/andreashasse/spectral"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:spectra, "~> 0.1.9"},
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
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md),
      exclude_patterns: ["lib/person.ex"]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"],
      filter_modules: fn module, _metadata ->
        module not in [Person, Person.Address]
      end
    ]
  end
end
