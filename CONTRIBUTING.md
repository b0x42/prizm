# Contributing

Contributions are welcome — whether it's a bug report, a feature idea, or a pull request. Every bit helps make Prizm better.

## Quick Start

```bash
git clone https://github.com/b0x42/prizm.git
cd prizm
cp Prizm/LocalConfig.xcconfig.template Prizm/LocalConfig.xcconfig
# Fill in your Apple Team ID in LocalConfig.xcconfig
open "Prizm/Prizm.xcodeproj"
```

No package managers needed. Build with `⌘R`, run tests with `⌘U`.

**Requirements:** macOS 26+, Xcode with Swift 6, a Bitwarden/Vaultwarden server for testing.

## Found a Bug? Have an Idea?

[Open an issue](https://github.com/b0x42/prizm/issues/new). A short description with steps to reproduce is plenty. Screenshots help too.

## Want to Submit Code?

1. Fork the repo, branch off `main`
2. Make your change — keep it focused (one thing per PR)
3. Run `⌘U` and make sure tests pass
4. [Open a PR](https://github.com/b0x42/prizm/compare)

That's it. No CLA, no lengthy process.

### What's welcome

- Bug fixes
- New features and cipher type support
- Accessibility and performance improvements
- Documentation and typo fixes
- Test coverage

### Conventions

- **Architecture:** Clean Architecture — protocols in `Domain/`, implementations in `Data/`, UI in `Presentation/`
- **Concurrency:** Swift 6 strict concurrency (`@MainActor` on view models, `actor` for services)
- **Naming:** `PascalCase` types, `camelCase` properties, `Impl` suffix for protocol implementations
- **Security:** never log secrets, use `privacy: .private` for PII, debug logging gated behind `--debug-mode`
- **Dependencies:** zero third-party deps (Argon2Swift is vendored) — let's keep it that way

## License

By contributing, you agree that your contributions will be licensed under the same terms as the project.
