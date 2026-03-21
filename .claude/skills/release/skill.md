---
name: release
description: Prepare and publish a new release of Spectral. Updates CHANGELOG.md, mix.exs, and README.md with version information, analyzes git commits to determine semantic version, and guides through the release process.
---

# Release Skill

You are helping to prepare a new release of the Spectral library.

## Step 1: Detect Current Version

Read `mix.exs` to determine the current version.

## Step 2: Analyze Changes

Check recent git commits since the last release:
```bash
git log --oneline --since="$(git log -1 --format=%ai $(git describe --tags --abbrev=0 2>/dev/null || echo HEAD))" 2>/dev/null || git log --oneline -20
```

Also check what files have changed:
```bash
git diff $(git describe --tags --abbrev=0 2>/dev/null || echo HEAD~20)..HEAD --stat
```

Analyze the commits and changes to understand:
- Are there breaking changes?
- Are there new features?
- Are there bug fixes or documentation updates?

## Step 3: Suggest Version Bump

Based on semantic versioning:
- **Major** (X.0.0): Breaking changes, incompatible API changes
- **Minor** (0.X.0): New features, backwards-compatible additions
- **Patch** (0.0.X): Bug fixes, documentation updates, dependency patches

Use the AskUserQuestion tool to present three options showing what the new version would be for each choice (major, minor, or patch). Indicate which one you recommend based on the changes.

## Step 4: Generate Changelog Entries

Based on the git commits and changes, draft changelog entries organized into sections:
- **Added**: New features
- **Changed**: Changes in existing functionality
- **Fixed**: Bug fixes
- **Deprecated**: Soon-to-be removed features
- **Removed**: Removed features
- **Security**: Security fixes

Only include sections that have entries. Keep entries concise and user-focused.

## Step 5: Update Files

After the user selects a version bump, update these files:

### mix.exs
- Update the `version:` field to the new version

### README.md
- Find and update the installation example: `{:spectral, "~> X.Y.Z"}`

### CHANGELOG.md
- Add a new version section at the top (after `[Unreleased]`, before the previous version)
- Use today's date in ISO format (YYYY-MM-DD)
- Include the changelog entries you generated
- Format:
  ```markdown
  ## [X.Y.Z] - YYYY-MM-DD

  ### Added
  - New feature 1

  ### Changed
  - Change 1

  ```

## Step 6: Run Quality Checks

```bash
make format && make ci
mix docs
```

All checks must pass before proceeding.

## Step 7: Create Release Branch and PR

Use the AskUserQuestion tool to ask whether to create a new release branch or commit to the current branch:
- **New branch** (`release/X.Y.Z`): creates a clean branch for the release PR
- **Current branch**: commits directly to whatever branch is currently checked out

Then proceed based on the answer:

**If new branch:**
1. Create and switch to a release branch:
   ```bash
   git checkout -b release/X.Y.Z
   ```

**Either way:**
2. Stage and commit the updated files:
   ```bash
   git add mix.exs CHANGELOG.md README.md
   git commit -m "Prepare release X.Y.Z"
   ```

**If new branch:**
3. Push and create a PR:
   ```bash
   git push -u origin release/X.Y.Z
   gh pr create --title "Release X.Y.Z" --body "..."
   ```
   Include the changelog entries for this version in the PR body. Return the PR URL to the user.

**If current branch:**
3. Push only — no PR needed since the release commit will be included in the branch's existing PR:
   ```bash
   git push
   ```
   Tell the user the release commit has been pushed to the current branch.

## Important Notes

- Do NOT run `make release` — the user will do that after the PR is merged
- Do NOT create git tags — `make release` handles tagging and publishing
- Do NOT merge the pull request — the user reviews and merges
- Try to write clear, user-focused changelog entries
- Group related changes together
- Omit internal refactorings unless they significantly impact users
