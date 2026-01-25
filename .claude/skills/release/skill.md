# release

Prepare and create a new release of Spectral, ensuring changelog and documentation are up to date.

## Instructions

You are tasked with preparing a new release of the Spectral library. This involves reviewing changes, updating version numbers, finalizing the changelog, and ensuring documentation is current. The user will run `make release` manually after this skill completes to handle tagging and publishing.

### Steps to Follow

1. **Review Current State**
   - Read `mix.exs` to identify the current version (e.g., `0.3.1`)
   - Read `CHANGELOG.md` to review unreleased changes
   - Check `git status` to ensure working directory is clean
   - Run `git log` to review recent commits since the last release

2. **Analyze Changes**
   Review the unreleased changes in `CHANGELOG.md` and recent commits to determine the appropriate version bump:

   - **Major version (X.0.0)**: Breaking changes, major API changes
     - Changed function signatures that break compatibility
     - Removed public functions
     - Changed behavior that breaks existing code

   - **Minor version (0.X.0)**: New features, non-breaking additions
     - New public functions or modules
     - New optional parameters
     - Dependency upgrades with new features
     - Significant new functionality

   - **Patch version (0.0.X)**: Bug fixes, minor improvements
     - Bug fixes
     - Documentation updates
     - Dependency patches without new features
     - Performance improvements without API changes

3. **Suggest Version Bump**
   Based on the analysis, present the user with a clear recommendation:

   ```
   Current version: X.Y.Z

   Recommended version bump: [MAJOR/MINOR/PATCH]
   New version: A.B.C

   Reasoning:
   - [List specific changes and why they justify this bump level]
   ```

   Use `AskUserQuestion` to confirm the version bump with options:
   - Patch (recommended) - if that's your recommendation
   - Minor - for feature additions
   - Major - for breaking changes
   - Custom - let user specify exact version

4. **Update CHANGELOG.md**
   - Move all `[Unreleased]` changes to a new version section
   - Add today's date in format `YYYY-MM-DD`
   - Ensure changes are categorized properly under:
     - `Added` - new features
     - `Changed` - changes in existing functionality
     - `Deprecated` - soon-to-be removed features
     - `Removed` - removed features
     - `Fixed` - bug fixes
     - `Security` - security fixes
   - Create a new empty `[Unreleased]` section at the top
   - Verify the changelog follows [Keep a Changelog](https://keepachangelog.com/) format

5. **Update Version Numbers**
   - Update version in `mix.exs` (line ~7: `version: "X.Y.Z"`)
   - Check if `README.md` installation example needs version update (only for major/minor changes)
   - Verify no other files contain hardcoded version numbers

6. **Verify Documentation**
   Review `README.md` to ensure it's current:
   - Installation instructions are correct
   - Examples work with current API
   - Features mentioned in changelog are documented
   - Requirements section is accurate
   - API changes are reflected in usage examples

   If documentation needs updates:
   - Update outdated examples
   - Add documentation for new features
   - Remove or update deprecated feature documentation

7. **Run Quality Checks**
   Execute the following commands to ensure everything is ready:
   ```bash
   mix format
   mix compile --warnings-as-errors
   mix test
   mix credo --strict
   mix dialyzer
   mix docs
   ```

   All checks must pass before proceeding.

8. **Review Changes**
   - Use `git diff` to show all changes made
   - Verify version numbers are consistent
   - Ensure changelog is complete and accurate
   - Check that README reflects current state

9. **Create Release Branch and Commit**
   - Create a release branch: `git checkout -b release-X.Y.Z`
   - Stage all changes: `git add mix.exs CHANGELOG.md README.md` (and any other modified files)
   - Create a commit with message: `Release X.Y.Z`
   - Show the commit for user review

10. **Create Pull Request**
    - Push the release branch to origin: `git push -u origin release-X.Y.Z`
    - Generate PR title and description:
      - **Title**: `Release X.Y.Z`
      - **Description**: Format based on changelog changes:
        ```markdown
        ## Changes

        - [List each change from the changelog version section]

        ## Release Checklist

        - [x] Version updated in mix.exs
        - [x] CHANGELOG.md updated
        - [x] All tests passing
        - [x] Documentation updated
        - [ ] PR reviewed and approved
        - [ ] Merge to main
        - [ ] Run `make release` to tag and publish
        ```
    - Present the suggested title and description to the user
    - Use `AskUserQuestion` to confirm or allow modifications:
      - Option 1: Use suggested title and description (recommended)
      - Option 2: Modify the description
    - If user chooses to modify, ask for the custom description
    - Create the PR using `gh pr create --title "..." --body "..."`
    - Show the PR URL

11. **Final Summary**
    Provide a comprehensive summary:
    ```
    Release X.Y.Z Ready

    Version bump: [patch/minor/major]
    Previous version: A.B.C
    New version: X.Y.Z

    Changes in this release:
    - [List all changes from changelog]

    Files modified:
    - mix.exs
    - CHANGELOG.md
    - README.md (if updated)

    Quality checks: ✓ All passed

    Branch created:
    - Branch: release-X.Y.Z
    - Commit: [commit hash] - "Release X.Y.Z"

    Pull Request:
    - PR #[number]: [PR URL]
    - Title: Release X.Y.Z

    Next steps:
    1. Review the pull request
    2. Once merged, run `make release` to tag and publish the release
    ```

### Important Notes

- **Semantic Versioning**: Follow [semver.org](https://semver.org/) strictly
- **Keep a Changelog**: Follow [keepachangelog.com](https://keepachangelog.com/) format
- **Clean Working Directory**: Ensure no uncommitted changes before starting
- **All Tests Must Pass**: Never release with failing tests
- **Documentation First**: Update docs before releasing, not after
- **Version Consistency**: Ensure version is updated everywhere it appears
- **PR Workflow**: This skill creates a pull request for review; after PR is merged, run `make release` to tag and publish
- **No Tagging**: This skill only prepares the release; `make release` handles tagging and publishing after PR is merged

### Pre-Release Checklist

Before creating the release commit, verify:
- [ ] All unreleased changes moved to versioned section in CHANGELOG.md
- [ ] New version number set in mix.exs
- [ ] README.md installation example updated (if major/minor bump)
- [ ] All examples in README.md tested and working
- [ ] All tests passing (`mix test`)
- [ ] No compilation warnings
- [ ] Code formatted (`mix format --check-formatted`)
- [ ] Type checking passes (`mix dialyzer`)
- [ ] Documentation builds (`mix docs`)
- [ ] Git working directory clean (except for release changes)

### Error Handling

If you encounter issues:
- **Test failures**: Fix the issues before proceeding with release
- **Documentation build failures**: Fix doctest or @doc issues
- **Dirty git state**: Ask user to commit or stash changes first
- **Missing quality tools**: Some checks (credo, dialyzer) may not be required if tools aren't installed

### Success Criteria

The release is ready when:
1. Version number updated in mix.exs
2. CHANGELOG.md has a new version section with today's date
3. All unreleased changes moved to the new version section
4. README.md is current and accurate
5. All quality checks pass
6. Release branch created (release-X.Y.Z)
7. Release commit created
8. Pull request created with appropriate title and description
9. User has clear instruction to merge PR and run `make release`

### User Interaction

- **Ask for confirmation** on the version bump recommendation
- **Ask if README needs updates** if you're uncertain
- **Show diffs** before committing so user can review
- **Present PR title and description** for user approval/modification before creating
- **Provide clear next steps** for merging PR and running `make release`

### What NOT to Do

- Do NOT create git tags (make release handles this after PR is merged)
- Do NOT merge the pull request (user will review and merge)
- Do NOT run `mix hex.publish` (make release handles this)
- Do NOT create GitHub releases automatically
- Do NOT release with failing tests or warnings
- Do NOT skip the changelog update
- Do NOT push tags (make release handles this)
