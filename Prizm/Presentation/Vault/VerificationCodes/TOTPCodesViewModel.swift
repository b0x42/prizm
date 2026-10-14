import Combine
import Foundation
import os.log

// MARK: - TOTPCodeState

/// What the UI shows for one item: a current code, or "unavailable" when the seed cannot be used.
enum TOTPCodeState: Equatable {
    case code(TOTPCode)
    case unavailable
}

// MARK: - TOTPCodesViewModel

/// Keeps the current TOTP code of every tracked item up to date, once per second.
///
/// One tracker serves both the detail-pane card (one item) and the Verification Codes list
/// (many items), so there is a single refresh loop to start, stop, and test.
///
/// Lifecycle (FR-010, FR-011): callers `start(items:)` from a view's `.task` and `stop()` when
/// the view disappears, the app is hidden or minimized, or the vault locks. `stop()` clears
/// every published code, so nothing stale is left to show on return.
///
/// Security: the seed lives in the already-decrypted `VaultItem`. It is read, handed to the
/// use case, and dropped on each pass; this type caches no seeds and logs no seeds or codes.
@MainActor
final class TOTPCodesViewModel: ObservableObject {

    // MARK: - Published state

    /// Keyed by item id. Only items that have a seed appear here.
    @Published private(set) var states: [String: TOTPCodeState] = [:]

    // MARK: - Dependencies

    private let generate: any GenerateTOTPCodeUseCase
    private let now: @MainActor () -> Date
    private let logger = Logger(subsystem: "com.prizm", category: "TOTPCodesViewModel")

    // MARK: - Loop state

    private var loop: Task<Void, Never>?
    /// Set only by `stop()` and cleared by `start(items:)`. While set, passes are ignored so a
    /// late in-flight pass cannot repopulate codes after the view has gone away.
    private var isStopped = false
    private var lastLoggedUnavailableCount = 0
    /// Counts completed passes; the test seam `waitForFirstPass()` observes it.
    private var passCount = 0
    private var passBaseline = 0

    /// - Parameters:
    ///   - generate: Produces the code for a seed at a moment in time.
    ///   - now: The clock. Injected so tests control time; defaults to the device clock
    ///     (the app does not correct for clock error).
    init(generate: any GenerateTOTPCodeUseCase, now: @escaping @MainActor () -> Date = { Date() }) {
        self.generate = generate
        self.now = now
    }

    deinit {
        loop?.cancel()
    }

    // MARK: - Control

    /// Starts (or restarts) the once-per-second refresh for `items`.
    func start(items: [VaultItem]) {
        loop?.cancel()
        isStopped = false
        passBaseline = passCount
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refreshNow(items: items)
                try? await Task.sleep(for: self.delayUntilNextSecond())
            }
        }
    }

    /// Stops refreshing and removes every published code.
    func stop() {
        isStopped = true
        loop?.cancel()
        loop = nil
        states = [:]
    }

    /// The clipboard value (digits only) for an item, or nil when it has no usable code.
    func copyValue(for itemId: String) -> String? {
        guard case .code(let code)? = states[itemId] else { return nil }
        return code.copyValue
    }

    // MARK: - One pass

    /// Recomputes the code for every item that has a seed, reading the clock once.
    /// Exposed (not private) so tests can drive passes without waiting for the loop.
    func refreshNow(items: [VaultItem]) async {
        guard !isStopped else { return }
        let moment = now()
        var next: [String: TOTPCodeState] = [:]
        var unavailable = 0

        for item in items {
            guard case .login(let login) = item.content,
                  let seed = login.totp,
                  !seed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { continue }
            do {
                next[item.id] = .code(try await generate.execute(seed: seed, at: moment))
            } catch {
                next[item.id] = .unavailable
                unavailable += 1
            }
        }

        // The task may have been cancelled or stopped while we awaited the use case.
        guard !isStopped, !Task.isCancelled else { return }
        if next != states { states = next }
        passCount += 1

        // Count only, never seeds or codes (Constitution §III, §V). Logged on change to avoid
        // one line per second.
        if unavailable != lastLoggedUnavailableCount {
            lastLoggedUnavailableCount = unavailable
            logger.error("Verification codes unavailable for \(unavailable, privacy: .public) item(s)")
        }
    }

    /// Test seam: suspends until a pass has completed since the last `start(items:)`.
    func waitForFirstPass() async {
        while passCount == passBaseline {
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    // MARK: - Timing

    /// Sleeps to the next whole second so countdowns tick in step with the clock (SC-004).
    private func delayUntilNextSecond() -> Duration {
        let seconds = now().timeIntervalSince1970
        let fraction = seconds - seconds.rounded(.down)
        return .milliseconds(Int((1 - fraction) * 1000))
    }
}
