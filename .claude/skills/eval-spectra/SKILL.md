---
name: eval-spectra
description: Evaluate a GitHub branch of the spectra Erlang library — switch mix.exs to the branch, inspect local changes, identify required wrapper updates, implement them. Usage: /eval-spectra <branch>
---

# Evaluate a spectra GitHub branch

Evaluate a new branch of the `spectra` Erlang library for use in this project. Called as:
`/eval-spectra <branch>`

The `spectra` repo is at `andreashasse/spectra`.

## Steps

### 1. Switch the dependency to the GitHub branch

Read `mix.exs` to find the current `:spectra` dependency entry. Replace it with a GitHub source pointing to the given branch:

```elixir
# Before (hex.pm pin or previous branch)
{:spectra, "~> x.y"}
# or
{:spectra, github: "andreashasse/spectra", branch: "old-branch"}

# After
{:spectra, github: "andreashasse/spectra", branch: "<branch>", override: true}
```

Then fetch the updated dependency:

```bash
mix deps.update spectra
```

If `mix deps.update` fails due to conflicts, investigate and resolve them before continuing.

### 2. Inspect what changed

The dependency is now available locally at `deps/spectra/`. Read its files directly — do **not** curl GitHub.

Start with:
- `deps/spectra/CHANGELOG.md` or `deps/spectra/CHANGES.md`
- `deps/spectra/README.md`
- All `.hrl` header files (record definitions, macros)
- All `.erl` source files that this project calls into

Compare against the previously pinned revision:

```bash
cd deps/spectra && git log --oneline <previous_ref>..HEAD
cd deps/spectra && git diff <previous_ref>..HEAD
```

If the previous ref is unclear, check the old `mix.lock` via `git diff mix.lock` or look at `git tags` in the dep.

### 3. Analyse the changes

For each meaningful change evaluate:

**New APIs** — New functions, callbacks, options, or record fields. For each, determine whether it should be exposed through the Spectral wrapper and how.

**Backwards compatibility** — Are any public APIs removed or signatures changed? Are record fields added, removed, or reordered? Flag each breaking change. Check every call site in `lib/` and `test/` that touches the changed interface.

**Correctness** — Does anything look buggy, incomplete, or inconsistent?

### 4. Flag problems and ask for direction

If any change appears buggy, harmful, or a poor fit for this project, present it clearly:

- Quote the problematic code from the dependency
- Explain the concern
- Suggest a concrete fix or workaround
- **Stop and ask the user for instructions** before proceeding further

### 5. Identify what needs to be implemented

Given the new capabilities, what should change in this project? Look for:

- New wrapper functions to expose
- Existing wrappers that need updating to match changed signatures
- Simpler implementations enabled by new APIs
- Dead code that can be removed

List them in priority order.

### 6. Implement changes

For each change (required fixes first, then improvements):

1. Write or update tests first in `test/` covering the new behaviour
2. Run `mix test` — confirm the tests fail as expected
3. Implement the change in `lib/`
4. Run `make format && make ci` — all checks must pass

If a change is backwards-incompatible and affects the public API of *this* project, flag it to the user before implementing.

### 7. Summary

Present a structured summary:

```
## Branch evaluation: spectra <branch>

### Changes in the branch
- <bullet per meaningful change>

### Backwards incompatible changes
- <none / list>

### What was unclear or underdocumented
- <list>

### Changes made to this project
- <bullet per change, with file references>

### Improvements not yet implemented (if any)
- <list with rationale>
```
