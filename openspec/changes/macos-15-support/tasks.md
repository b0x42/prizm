# Tasks

- [x] Verify the original deployment target blocks tests on macOS 15.
- [x] Lower app and test deployment targets; add CI coverage for macOS 15 and 26.
- [x] Update current documentation and the release-time Homebrew requirement.
- [x] Reproduce and fix the isolated-deinitializer crash without changing member isolation.
- [x] Fix code-list row selection and rerun the existing UI regression.
- [x] Run unit tests and server-free UI smoke tests on macOS 15.
- [x] Build, install and launch a Release app on macOS 15; review the final diff.

## Verification

Local environment: macOS 15.7.4, Xcode 26.3. UI and Release builds use the original
`de.b0x42.Prizm` bundle identifier in the ignored `LocalConfig.xcconfig`.

| Check | Result |
|---|---|
| Original deployment target on macOS 15 | Test launch rejected (target requires macOS 26) |
| Synchronous task-local regression before fix | Crashes with and without AddressSanitizer |
| Unit/integration suite after fix, AddressSanitizer enabled | 550 passed, 0 failed |
| Code-list selection before gesture fix | Existing UI test fails |
| Verification-code UI suite after gesture fix | 9 passed, 0 failed |
| Release build (arm64 + x86_64) and static analyzer | Passed |
| Ad-hoc Release signature, sandbox and hardened runtime | Verified |
| Installed Release launch on macOS 15.7.4 | Login screen displayed |
| Xcode project, workflow YAML, cask-update fixture, diff whitespace | Passed |

No project lint configuration exists. macOS 26 CI and live-server/biometric login
were not run locally. Local UI tests use ad-hoc signing; no signing secrets are committed.
