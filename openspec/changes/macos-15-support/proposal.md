# Proposal

## Why

Prizm's deployment target prevents macOS 15 users from launching the app, although
the existing source builds for macOS 15 with Xcode 26. Supporting Sequoia also
matches the Constitution's current-and-previous macOS release policy.

## What Changes

- Lower the app, unit-test and UI-test deployment targets to macOS 15.
- Avoid Swift's crashing synthesized isolated deinitializers on macOS 15 while
  preserving the existing actor isolation of every member.
- Install the code-row copy gesture only in the detail card so list selection works on macOS 15.
- Build and run unit tests on macOS 15 and 26 in CI.
- Update current platform documentation and Homebrew requirements for future releases.

## Impact

Explicit nonisolated deinitializers work around a reproduced Swift runtime crash;
no storage, cryptography, dependency or public API changes. Xcode 26 remains required
to build. Already published macOS 26-only downloads remain unchanged.
