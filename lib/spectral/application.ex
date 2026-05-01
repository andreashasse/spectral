defmodule Spectral.Application do
  use Application

  @impl Application
  def start(_type, _args) do
    register_default_codecs()
    {:ok, self()}
  end

  @doc """
  Registers the default codecs for built-in types. This is called automatically when the application starts
  """
  def register_default_codecs() do
    default_codecs = [
      {{MapSet, {:type, :t, 0}}, Spectral.Codec.MapSet},
      {{MapSet, {:type, :t, 1}}, Spectral.Codec.MapSet},
      {{Date, {:type, :t, 0}}, Spectral.Codec.Date},
      {{DateTime, {:type, :t, 0}}, Spectral.Codec.DateTime},
      {{String, {:type, :t, 0}}, Spectral.Codec.String}
    ]

    existing = Application.get_env(:spectra, :codecs, %{})
    merged = Map.merge(Map.new(default_codecs), existing)
    Application.put_env(:spectra, :codecs, merged, persistent: true)
  end
end
