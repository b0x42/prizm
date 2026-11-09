# Implementation plan

Architecture, integration points and Keychain/transport decisions are defined in [design.md](design.md). Required behavior is defined in [specs/client-certificates/spec.md](specs/client-certificates/spec.md).

Implement and validate packages 0–3 using [tasks.md](tasks.md). Do not extend into certificate renewal, multiple endpoint origins, attachments or private icon services in this prototype. Test both unsigned transport behavior and signed sandbox persistence/restart; record evidence and remaining manual checks in [validation.md](validation.md).
