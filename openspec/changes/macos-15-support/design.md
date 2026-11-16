# Design

## Deployment and validation

Set all six app/unit/UI Debug and Release deployment targets to `15.0`. Keep the
existing SDK and Swift settings. The compiler accepts the source at this deployment
target, but runtime tests expose the isolated-deinitializer issue below.

Add macOS 15 to the existing CI job as a matrix entry alongside macOS 26. Running
the existing hosted tests on Sequoia guards against raising the minimum runtime
again. Validate Debug tests and a Release app locally on macOS 15, including launch
and the existing server-free verification-code UI journeys.

## Swift runtime compatibility

With Xcode 26.3 and macOS 15.7.4, synthesized isolated deinitializers crash in
`swift::TaskLocal::StopLookupScope` when synchronously released under task-local
storage. The full suite reproduces 12 crashes; a standalone repro and a focused
test also crash without AddressSanitizer. This matches
[swiftlang/swift#88036](https://github.com/swiftlang/swift/issues/88036).

Explicit `nonisolated deinit {}` avoids that runtime path without changing member
isolation or stored-property destruction. Apply it to the handwritten classes
whose object files reference the affected runtime function; preserve existing
deinitializers and their cleanup. The generated asset bundle-locator class only serves
as a type token for `Bundle(for:)` and is never instantiated.

Changing the module's default actor isolation was rejected: it produces numerous
concurrency errors and would require migrating unrelated types and conformances.
Disabling the isolated-deinit feature by compiler flags did not fix the repro.
Existing tests and a focused task-local destruction regression cover the fix.

The existing attachment slice test fixture also needs `[UInt8](plainData)` when
concatenating byte arrays; without it the test target fails to compile.

## Code-list selection

On macOS 15, the existing `testList_clickingRow_opensItemInDetailPane` fails because
`TOTPCodeRowView` registers a tap gesture even when `copiesOnTap` is false. The
inactive copy handler consumes the list-selection click. Make that gesture optional:
the detail card keeps tap-to-copy, while the list receives native selection clicks.
The separate copy button stays available in both contexts.

## Distribution

The checked-in cask still downloads v1.5.1, whose app requires macOS 26. Keep that
requirement until its download changes. The release workflow updates the separate
Homebrew tap's minimum to Sequoia together with the next release version and hash.
Document this distinction so macOS 15 users build from source until that release.

No data migration, entitlement changes or additional dependencies are needed.
