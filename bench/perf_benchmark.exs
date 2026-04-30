## Performance benchmark for Spectral.
##
## Measures round-trip encode+decode throughput across four cache modes:
##   1. Persistent cache (persistent_term)
##   2. Local cache (default — per-call process-dictionary cache)
##   3. No cache
##   4. Persistent cache, cleared between every call
##
## Run with:
##   mix run bench/perf_benchmark.exs

## ─── Data model ─────────────────────────────────────────────────────────────

defmodule Perf.Address do
  use Spectral

  defstruct [:street, :city, :zip_code, :country, :state, :type, :coordinates, :notes]

  @type address_type :: :home | :work | :billing | :shipping

  @type coordinates :: %{required(:lat) => float(), required(:lng) => float()}

  spectral title: "Address", description: "A postal address with optional geo-coordinates"
  @type t :: %Perf.Address{
          street: String.t(),
          city: String.t(),
          zip_code: String.t(),
          country: String.t(),
          state: String.t() | nil,
          type: address_type(),
          coordinates: coordinates() | nil,
          notes: [String.t()]
        }
end

defmodule Perf.User do
  use Spectral

  defstruct [
    :id,
    :username,
    :email,
    :role,
    :status,
    :age,
    :score,
    :tags,
    :permissions,
    :metadata,
    :created_at,
    :last_seen,
    :phone,
    :addresses,
    :tag_scores
  ]

  @type role :: :admin | :editor | :viewer | :moderator

  @type status :: :active | :inactive | :suspended | :pending

  @type permission ::
          :read
          | :write
          | :delete
          | :admin
          | :publish
          | :deploy
          | :billing
          | :moderate
          | :ban_user
          | :audit

  # String validated against an e-mail pattern via regex constraint.
  spectral type_parameters: %{pattern: "^[a-z0-9._%+\\-]+@[a-z0-9.\\-]+\\.[a-z]{2,}$"}
  @type email :: String.t()

  # Map of string label → integer score.
  @type tag_scores :: %{String.t() => integer()}

  spectral title: "User", description: "A platform user with addresses and activity metadata"
  @type t :: %Perf.User{
          id: pos_integer(),
          username: String.t(),
          email: email(),
          role: role(),
          status: status(),
          age: non_neg_integer() | nil,
          score: float(),
          tags: MapSet.t(String.t()),
          permissions: [permission()],
          metadata: %{String.t() => String.t()},
          created_at: DateTime.t(),
          last_seen: DateTime.t() | nil,
          phone: String.t() | nil,
          addresses: [Perf.Address.t()],
          tag_scores: tag_scores()
        }

  @type users :: [t()]
end

## ─── Sample JSON payloads (~1.5 KB each) ────────────────────────────────────

defmodule Perf.Samples do
  def all do
    [json1(), json2(), json3(), json4(), json5()]
  end

  def json1 do
    ~s([
      {
        "id": 1, "username": "alice_wonder", "email": "alice@example.com",
        "role": "admin", "status": "active", "age": 28, "score": 4.75,
        "tags": ["elixir", "erlang", "otp", "distributed"],
        "permissions": ["read", "write", "delete", "admin"],
        "metadata": {"department": "engineering", "team": "backend", "level": "senior"},
        "created_at": "2023-01-15T10:30:00.000Z",
        "last_seen": "2024-03-20T14:22:18.000Z",
        "phone": "+1-555-0100",
        "addresses": [
          {
            "street": "123 Elm Street", "city": "Springfield", "zip_code": "12345",
            "country": "US", "state": "IL", "type": "home",
            "coordinates": {"lat": 39.7817, "lng": -89.6501},
            "notes": ["Near the park", "Second floor"]
          },
          {
            "street": "456 Oak Avenue", "city": "Portland", "zip_code": "97201",
            "country": "US", "state": "OR", "type": "work",
            "coordinates": null, "notes": []
          }
        ],
        "tag_scores": {"erlang": 95, "elixir": 88, "javascript": 72, "python": 65}
      },
      {
        "id": 2, "username": "bob_builder", "email": "bob@example.com",
        "role": "editor", "status": "active", "age": 35, "score": 3.25,
        "tags": ["rust", "c", "systems"],
        "permissions": ["read", "write"],
        "metadata": {"department": "infrastructure", "team": "platform"},
        "created_at": "2022-06-01T08:00:00.000Z",
        "last_seen": null, "phone": null,
        "addresses": [
          {
            "street": "789 Pine Road", "city": "Seattle", "zip_code": "98101",
            "country": "US", "state": "WA", "type": "home",
            "coordinates": {"lat": 47.6062, "lng": -122.3321},
            "notes": ["Apartment 3B"]
          }
        ],
        "tag_scores": {"rust": 92, "c": 85, "go": 78}
      }
    ])
  end

  def json2 do
    ~s([
      {
        "id": 10, "username": "carol_cipher", "email": "carol@acme.org",
        "role": "moderator", "status": "active", "age": 42, "score": 4.9,
        "tags": ["security", "cryptography", "networking"],
        "permissions": ["read", "write", "moderate", "ban_user"],
        "metadata": {"department": "trust-safety", "team": "content", "clearance": "high"},
        "created_at": "2021-11-03T09:15:00.000Z",
        "last_seen": "2024-04-01T07:05:55.000Z",
        "phone": "+44-20-7946-0958",
        "addresses": [
          {
            "street": "10 Downing Lane", "city": "London", "zip_code": "SW1A 0AA",
            "country": "GB", "state": null, "type": "home",
            "coordinates": {"lat": 51.5034, "lng": -0.1276},
            "notes": ["Buzzer code: 4712", "No post on Sundays"]
          },
          {
            "street": "1 Canary Wharf", "city": "London", "zip_code": "E14 5AB",
            "country": "GB", "state": null, "type": "work",
            "coordinates": {"lat": 51.5055, "lng": -0.0235},
            "notes": []
          },
          {
            "street": "99 High Street", "city": "Oxford", "zip_code": "OX1 4BH",
            "country": "GB", "state": null, "type": "billing",
            "coordinates": null, "notes": ["Care of: J. Smith"]
          }
        ],
        "tag_scores": {"security": 98, "cryptography": 90, "networking": 83, "linux": 76}
      },
      {
        "id": 11, "username": "dan_dev", "email": "dan@startup.io",
        "role": "viewer", "status": "pending", "age": null, "score": 1.0,
        "tags": ["python", "ml", "data"],
        "permissions": ["read"],
        "metadata": {"plan": "free", "source": "signup"},
        "created_at": "2024-04-28T22:44:10.000Z",
        "last_seen": null, "phone": null,
        "addresses": [],
        "tag_scores": {"python": 80, "ml": 75}
      }
    ])
  end

  def json3 do
    ~s([
      {
        "id": 20, "username": "eve_ops", "email": "eve@cloud.dev",
        "role": "admin", "status": "active", "age": 31, "score": 4.5,
        "tags": ["kubernetes", "docker", "terraform", "aws"],
        "permissions": ["read", "write", "deploy", "admin", "billing"],
        "metadata": {"team": "sre", "on_call": "true", "timezone": "US/Pacific"},
        "created_at": "2020-03-10T16:00:00.000Z",
        "last_seen": "2024-04-29T23:59:59.000Z",
        "phone": "+1-415-555-0199",
        "addresses": [
          {
            "street": "2000 Market Street", "city": "San Francisco", "zip_code": "94102",
            "country": "US", "state": "CA", "type": "home",
            "coordinates": {"lat": 37.7749, "lng": -122.4194},
            "notes": ["Leave packages at front desk"]
          }
        ],
        "tag_scores": {"kubernetes": 97, "terraform": 91, "aws": 89, "gcp": 82, "azure": 70}
      },
      {
        "id": 21, "username": "frank_fonts", "email": "frank@design.co",
        "role": "editor", "status": "inactive", "age": 27, "score": 2.8,
        "tags": ["figma", "sketch", "css"],
        "permissions": ["read", "write"],
        "metadata": {"department": "design", "team": "ui"},
        "created_at": "2023-07-19T11:11:11.000Z",
        "last_seen": "2023-12-31T23:59:00.000Z",
        "phone": null,
        "addresses": [
          {
            "street": "5 Studio Row", "city": "Brooklyn", "zip_code": "11201",
            "country": "US", "state": "NY", "type": "work",
            "coordinates": {"lat": 40.6892, "lng": -73.9442},
            "notes": []
          },
          {
            "street": "88 Prospect Park West", "city": "Brooklyn", "zip_code": "11215",
            "country": "US", "state": "NY", "type": "home",
            "coordinates": {"lat": 40.6655, "lng": -73.9669},
            "notes": ["Intercom: F. Fonts"]
          }
        ],
        "tag_scores": {"figma": 95, "css": 88, "sketch": 72}
      }
    ])
  end

  def json4 do
    ~s([
      {
        "id": 30, "username": "grace_hops", "email": "grace@legacy.net",
        "role": "admin", "status": "active", "age": 55, "score": 5.0,
        "tags": ["cobol", "fortran", "assembly", "c", "ada"],
        "permissions": ["read", "write", "delete", "admin", "audit"],
        "metadata": {"title": "Principal Engineer", "years_exp": "30", "clearance": "top"},
        "created_at": "1994-01-01T00:00:00.000Z",
        "last_seen": "2024-04-30T12:00:00.000Z",
        "phone": "+1-202-555-0001",
        "addresses": [
          {
            "street": "1 Navy Yard Plaza", "city": "Washington", "zip_code": "20374",
            "country": "US", "state": "DC", "type": "work",
            "coordinates": {"lat": 38.8752, "lng": -77.0079},
            "notes": ["Visitor badge required", "No cameras beyond reception"]
          },
          {
            "street": "422 Cherry Blossom Ave", "city": "Arlington", "zip_code": "22201",
            "country": "US", "state": "VA", "type": "home",
            "coordinates": {"lat": 38.8816, "lng": -77.0910},
            "notes": []
          },
          {
            "street": "PO Box 4422", "city": "McLean", "zip_code": "22101",
            "country": "US", "state": "VA", "type": "billing",
            "coordinates": null, "notes": []
          }
        ],
        "tag_scores": {"cobol": 99, "fortran": 95, "c": 92, "ada": 88, "assembly": 85}
      }
    ])
  end

  def json5 do
    ~s([
      {
        "id": 40, "username": "hiro_hacks", "email": "hiro@bytecraft.jp",
        "role": "editor", "status": "active", "age": 24, "score": 3.9,
        "tags": ["rust", "wasm", "embedded"],
        "permissions": ["read", "write", "publish"],
        "metadata": {"locale": "ja-JP", "plan": "pro", "newsletter": "true"},
        "created_at": "2023-09-01T00:00:00.000Z",
        "last_seen": "2024-04-15T06:30:00.000Z",
        "phone": "+81-3-1234-5678",
        "addresses": [
          {
            "street": "2-11-3 Meguro", "city": "Tokyo", "zip_code": "153-0063",
            "country": "JP", "state": null, "type": "home",
            "coordinates": {"lat": 35.6322, "lng": 139.7154},
            "notes": ["Floor 7", "Beside konbini"]
          }
        ],
        "tag_scores": {"rust": 93, "wasm": 87, "embedded": 81, "zig": 70}
      },
      {
        "id": 41, "username": "isla_infra", "email": "isla@infra.cloud",
        "role": "viewer", "status": "suspended", "age": 29, "score": 2.1,
        "tags": ["monitoring", "logs"],
        "permissions": ["read"],
        "metadata": {"reason": "billing_issue", "escalation": "pending"},
        "created_at": "2023-02-14T14:00:00.000Z",
        "last_seen": "2024-01-10T11:00:00.000Z",
        "phone": "+1-888-555-0042",
        "addresses": [
          {
            "street": "303 Cloud Nine Blvd", "city": "Austin", "zip_code": "73301",
            "country": "US", "state": "TX", "type": "billing",
            "coordinates": {"lat": 30.2672, "lng": -97.7431},
            "notes": []
          },
          {
            "street": "707 Longhorn Drive", "city": "Austin", "zip_code": "78701",
            "country": "US", "state": "TX", "type": "home",
            "coordinates": {"lat": 30.2712, "lng": -97.7398},
            "notes": ["Gate code: 8844"]
          }
        ],
        "tag_scores": {"monitoring": 72, "logs": 68, "metrics": 60}
      }
    ])
  end
end

## ─── Benchmark runner ────────────────────────────────────────────────────────

defmodule PerfBenchmark do
  # Target wall-clock time per round in microseconds.
  @target_us 5_000_000

  # Calibration: number of iterations used to estimate per-call cost.
  @calibration_iters 5

  def run do
    Application.put_env(:spectra, :codecs, %{
      {DateTime, {:type, :t, 0}} => Spectral.Codec.DateTime,
      {MapSet, {:type, :t, 1}} => Spectral.Codec.MapSet
    })

    IO.puts("\n=== Spectral Performance Benchmark ===")
    IO.puts("Target time per round: #{div(@target_us, 1_000)} ms")

    jsons = Perf.Samples.all()
    sizes = Enum.map(jsons, &byte_size/1)
    IO.puts("Sample JSON sizes: #{Enum.join(sizes, ", ")} bytes")

    warmup(jsons)

    run_round("Round 1 — persistent cache", jsons, fn -> :persistent end, fn -> :ok end)
    run_round("Round 2 — local cache (default)", jsons, fn -> :local end, fn -> :ok end)
    run_round("Round 3 — no cache", jsons, fn -> :none end, fn -> :ok end)

    run_round(
      "Round 4 — persistent cache, cleared between calls",
      jsons,
      fn -> :persistent end,
      fn ->
        :spectra_module_types.clear(Perf.User)
        :spectra_module_types.clear(Perf.Address)
      end
    )
  end

  defp warmup(jsons) do
    IO.puts("\nWarming up (persistent cache)...")
    Application.put_env(:spectra, :module_types_cache, :persistent)

    for _ <- 1..10, json <- jsons do
      {:ok, users} = Spectral.decode(json, Perf.User, :users)
      {:ok, _} = Spectral.encode(users, Perf.User, :users)
    end

    IO.puts("Warm-up complete.")
  end

  defp run_round(label, jsons, set_cache_fn, between_calls_fn) do
    IO.puts("\n--- #{label} ---")
    Application.put_env(:spectra, :module_types_cache, set_cache_fn.())

    n = length(jsons)
    call = fn i ->
      json = Enum.at(jsons, rem(i, n))
      between_calls_fn.()

      {time, _} =
        :timer.tc(fn ->
          {:ok, users} = Spectral.decode(json, Perf.User, :users)
          {:ok, _} = Spectral.encode(users, Perf.User, :users)
        end)

      time
    end

    # Calibrate: measure a few iterations to estimate per-call cost.
    cal_times = for i <- 0..(@calibration_iters - 1), do: call.(i)
    mean_cal = Enum.sum(cal_times) / @calibration_iters
    iterations = max(1, round(@target_us / mean_cal))

    IO.puts("Calibrated iterations: #{iterations}")

    times = for i <- 0..(iterations - 1), do: call.(i)

    print_stats(times)
  end

  defp print_stats(times) do
    sorted = Enum.sort(times)
    n = length(times)
    mean = Enum.sum(times) / n
    median = Enum.at(sorted, div(n, 2))
    min_t = List.first(sorted)
    max_t = List.last(sorted)
    variance = Enum.sum(Enum.map(times, fn t -> :math.pow(t - mean, 2) end)) / n
    std_dev = :math.sqrt(variance)

    IO.puts("Mean:       #{Float.round(mean / 1000, 2)} ms")
    IO.puts("Median:     #{Float.round(median / 1000, 2)} ms")
    IO.puts("Min:        #{Float.round(min_t / 1000, 2)} ms")
    IO.puts("Max:        #{Float.round(max_t / 1000, 2)} ms")
    IO.puts("Std dev:    #{Float.round(std_dev / 1000, 2)} ms")
    IO.puts("Throughput: #{Float.round(1_000_000 / mean, 1)} round-trips/sec")
  end
end

PerfBenchmark.run()
