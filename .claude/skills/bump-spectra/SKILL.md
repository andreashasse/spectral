# bump-spectra

Bump the spectra dependency to the latest version from hex.pm and verify compatibility.

## Instructions

You are tasked with updating the `spectra` Erlang library dependency to the latest version. Since Spectral is a thin Elixir wrapper around spectra, this is a critical operation that requires careful verification.

### Steps to Follow

1. **Check Current Version**
   - Read `mix.exs` to identify the current spectra version requirement
   - Note the current version constraint (e.g., `~> 0.3.0`)

2. **Fetch Latest Version from Hex.pm**
   - Use `mix hex.info spectra` to get information about the latest available version
   - Alternatively, fetch from https://hex.pm/api/packages/spectra to get version information
   - Identify the latest stable version (non-pre-release)

3. **Review Changelog/Release Notes**
   - Check for breaking changes in the spectra releases between the current and target versions
   - Look for:
     - API changes that might affect the wrapper functions
     - New features that could be exposed through the Spectral wrapper
     - Deprecations or removed functionality
     - Bug fixes that might affect behavior

4. **Update Dependencies**
   - Update the version constraint in `mix.exs` (line 27: `{:spectra, "~> X.Y.Z"}`)
   - Update the installation example in `README.md` if the major/minor version changes
   - Run `mix deps.get` to fetch the new version
   - Run `mix deps.update spectra` to ensure the dependency is updated

5. **Verify Wrapper Compatibility**
   Check if the Spectral wrapper modules need updates:

   - **`lib/spectral.ex`**: Review if `encode/4`, `decode/4`, and `schema/3` still properly delegate to `:spectra`
   - **`lib/spectral/openapi.ex`**: Verify OpenAPI builder functions still work with `:spectra_openapi`
   - Look for:
     - New functions in spectra that should be exposed
     - Changed function signatures
     - New options or parameters that should be supported
     - Deprecated functions that need migration

6. **Update Documentation**
   - Check if `README.md` needs updates for:
     - New features from spectra
     - Changed behavior or limitations
     - Updated examples
     - Version numbers in installation instructions
   - Update `CLAUDE.md` if architectural changes are needed

7. **Run Tests and Checks**
   Execute the following commands in sequence:
   ```bash
   mix format
   mix compile --force
   mix test
   mix credo
   mix dialyzer
   ```

   If any tests fail:
   - Investigate the root cause
   - Determine if it's a breaking change in spectra
   - Update the wrapper code or tests as needed
   - Re-run the test suite

8. **Final Verification**
   - Ensure all tests pass
   - Verify the code is properly formatted
   - Check that no new warnings appear
   - Review the changes you've made

9. **Summary Report**
   Provide a summary including:
   - Old version → New version
   - List of files modified
   - Any breaking changes discovered
   - Any new features that could be exposed
   - Any wrapper code changes made
   - Test results
   - Recommendations for follow-up work (if any)

### Important Notes

- **Always run tests**: The test suite includes doctests, so ensure all examples in documentation still work
- **Check for new functionality**: spectra might have added new features worth exposing in Spectral
- **Maintain backward compatibility**: Try to avoid breaking changes in the Spectral wrapper unless necessary
- **Type safety**: Ensure type specifications remain accurate after the update
- **Format first**: Always run `mix format` before running tests

### Error Handling

If you encounter errors:
- **Compilation errors**: The API likely changed; investigate the spectra changelog and update wrapper code
- **Test failures**: Compare behavior changes and decide if tests or code need updating
- **Dependency conflicts**: Check if other dependencies need updating for compatibility
- **Type errors (dialyzer)**: Type specifications might need adjustment based on spectra changes

### Success Criteria

The update is successful when:
1. The latest stable version of spectra is specified in mix.exs
2. All tests pass (`mix test`)
3. No compilation warnings or errors
4. Code is properly formatted (`mix format`)
5. Documentation is updated to reflect any changes
6. A clear summary of changes has been provided
