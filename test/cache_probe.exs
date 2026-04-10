Application.ensure_all_started(:spectra)
Application.put_env(:spectra, :module_types_cache, :persistent)

Application.put_env(:spectra, :codecs, %{
  {MapSet, {:type, :t, 0}} => Spectral.Codec.MapSet,
  {MapSet, {:type, :t, 1}} => Spectral.Codec.MapSet,
  {DateTime, {:type, :t, 0}} => Spectral.Codec.DateTime
})

json =
  ~s({"id":1001,"username":"alice_johnson","email":"alice.johnson@techcorp.example.com","phone":"+1-415-555-0101","role":"admin","active":true,"score":8750,"rating":4.87,"tags":["erlang","distributed","backend","functional"],"properties":{"level":10,"quota":5000,"retries":3,"timeout":30,"max_sessions":5},"created_at":"2021-03-15T09:00:00.000Z","last_login":"2024-04-01T14:30:22.500Z","addresses":[{"street":"742 Evergreen Terrace","city":"Springfield","zip_code":"62701","country":"United States","lat":39.7817,"lon":-89.6501,"unit":"3B","tags":["home","primary","billing"],"meta":{"timezone":"America/Chicago","verified":"true","access_notes":"Buzzer 3B","resident_since":"2021-03-15"}}],"notes":["note 1"]})

# Prime everything
for _ <- 1..5, do: :spectra.decode(:json, BenchUser, :t, json, [])

# Count persistent_term entries before and after 1 decode
before_count = length(:persistent_term.get())
:spectra.decode(:json, BenchUser, :t, json, [])
after_count = length(:persistent_term.get())

IO.puts(
  "persistent_term entries before: #{before_count}, after: #{after_count}, delta: #{after_count - before_count}"
)

# Do 10 more decodes and count again
for _ <- 1..10, do: :spectra.decode(:json, BenchUser, :t, json, [])
final_count = length(:persistent_term.get())
IO.puts("After 10 more decodes: #{final_count} entries")

# Check if there's something writing to persistent_term per decode
# by instrumenting - look at erlang:statistics
before_stats = :erlang.statistics(:reductions)
:spectra.decode(:json, BenchUser, :t, json, [])
after_stats = :erlang.statistics(:reductions)
IO.puts("Reductions for one decode: #{elem(after_stats, 0) - elem(before_stats, 0)}")

# Compare with v0.10.0 baseline: check if pattern matching on Config record is slow
# by creating a record and accessing a field many times
sp_config =
  {:sp_config, true, false,
   %{
     {MapSet, {:type, :t, 0}} => Spectral.Codec.MapSet,
     {MapSet, {:type, :t, 1}} => Spectral.Codec.MapSet,
     {DateTime, {:type, :t, 0}} => Spectral.Codec.DateTime
   }}

{t_access, _} =
  :timer.tc(fn ->
    for _ <- 1..1_000_000 do
      # Simulate Config#sp_config.module_types_cache
      elem(sp_config, 1)
    end
  end)

IO.puts("1M record field accesses: #{t_access}us")

# Let's check if the issue is in spectra_type:get_meta being called millions of times
# The profiler showed 2640 calls - that's manageable
# But what about spectra_type:update_meta? 1790 calls

# Let's run a real micro-benchmark of the from_json traversal steps
# by calling it with timing on each field type

type_info = :spectra_module_types.get(BenchUser, :persistent)
# Get properties field type
t_type = :spectra_type_info.get_type(type_info, :t, 0)
fields = elem(t_type, 1)
props_field = Enum.find(fields, fn f -> elem(f, 2) == :properties end)
