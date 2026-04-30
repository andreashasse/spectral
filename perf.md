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
