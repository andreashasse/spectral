Performance tests are run on a MacBook M3 Pro.

Each round runs for ~5 seconds (calibrated). A round-trip is one decode + one encode of a ~1.5 KB JSON payload containing 1–2 users with 0–3 addresses each.

# Version 0.12.0

## Round 1 — persistent cache
Mean:       0.05 ms
Median:     0.04 ms
Min:        0.03 ms
Max:        0.31 ms
Std dev:    0.02 ms
Throughput: 20712.0 round-trips/sec

## Round 2 — local cache (default)
Mean:       7.96 ms
Median:     7.90 ms
Min:        7.21 ms
Max:        10.45 ms
Std dev:    0.37 ms
Throughput: 125.7 round-trips/sec

## Round 3 — no cache
Mean:       206.44 ms
Median:     211.67 ms
Min:        160.12 ms
Max:        259.47 ms
Std dev:    24.43 ms
Throughput: 4.8 round-trips/sec

## Round 4 — persistent cache, cleared between calls
Mean:       0.40 ms
Median:     0.41 ms
Min:        0.05 ms
Max:        30.98 ms
Std dev:    0.37 ms
Throughput: 2486.3 round-trips/sec

# Version 0.12.1

Includes `Spectral.Codec.String`. `Perf.Address` moved to a compiled `.ex` file without `use Spectral` so spectra resolves it via BEAM abstract code — this makes the cache mode differences visible (previously Address had its own cache entry that was always warm).

## Round 1 — persistent cache
Mean:       0.05 ms
Median:     0.04 ms
Min:        0.03 ms
Max:        10.11 ms
Std dev:    0.07 ms
Throughput: 21869.1 round-trips/sec

## Round 2 — local cache (default)
Mean:       0.23 ms
Median:     0.21 ms
Min:        0.14 ms
Max:        15.18 ms
Std dev:    0.15 ms
Throughput: 4282.0 round-trips/sec

## Round 3 — no cache
Mean:       1.04 ms
Median:     1.01 ms
Min:        0.72 ms
Max:        2.17 ms
Std dev:    0.11 ms
Throughput: 961.3 round-trips/sec

## Round 4 — persistent cache, cleared between calls
Mean:       0.22 ms
Median:     0.23 ms
Min:        0.03 ms
Max:        1.28 ms
Std dev:    0.08 ms
Throughput: 4528.3 round-trips/sec
