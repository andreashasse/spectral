defmodule Spectral.MixProject do
  use Mix.Project

  def project do
    [
      app: :spectral,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps(),
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
      {:dialyxir, "~> 1.4.7", only: [:dev], runtime: false}
    ]
  end

  defp package() do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/andreashasse/spectral"}
    ]
  end
end
