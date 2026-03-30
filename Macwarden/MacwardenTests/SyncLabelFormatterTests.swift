import XCTest
@testable import Macwarden

/// Tests for `Date.syncStatusLabel(relativeTo:calendar:)` — the relative-label formatter
/// used by the vault browser sidebar's sync status view.
///
/// Tier evaluation order (calendar day first, then elapsed time for same-day syncs):
///   1. Future timestamp        → "Synced just now"
///   2. Previous calendar year  → "Synced [Month Day, Year]"
///   3. 2+ calendar days ago    → "Synced [Month Day]"
///   4. Previous calendar day   → "Synced yesterday"
///   5. 0–59 seconds elapsed    → "Synced just now"
///   6. 60–3599 seconds elapsed → "Synced 1 minute ago" / "Synced X minutes ago"
///   7. 3600+ seconds, same day → "Synced 1 hour ago" / "Synced X hours ago"
final class SyncLabelFormatterTests: XCTestCase {

    // Fixed reference point: 2026-03-28 14:00:00 UTC, on a Saturday.
    private let now: Date = {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 3; comps.day = 28
        comps.hour = 14;   comps.minute = 0; comps.second = 0
        comps.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: comps)!
    }()

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone  = TimeZone(identifier: "UTC")!
        // Pin locale so Date.FormatStyle produces deterministic English month names
        // ("Mar") regardless of the machine's system locale.
        c.locale    = Locale(identifier: "en_US_POSIX")
        return c
    }()

    // MARK: - Nil

    func testNilDate_returnsNeverSynced() {
        let result = Optional<Date>.none.syncStatusLabel(relativeTo: now, calendar: calendar)
        XCTAssertEqual(result, "Never synced")
    }

    // MARK: - Future timestamp (clock skew guard)

    func testFutureDate_returnsJustNow() {
        let future = now.addingTimeInterval(3600)
        XCTAssertEqual(future.syncStatusLabel(relativeTo: now, calendar: calendar), "Synced just now")
    }

    // MARK: - Previous calendar year

    func testPreviousYear_includesYear() {
        // 2025-03-26 — different year from now (2026)
        var comps = DateComponents()
        comps.year = 2025; comps.month = 3; comps.day = 26
        comps.hour = 10; comps.timeZone = TimeZone(identifier: "UTC")
        let date = calendar.date(from: comps)!

        let result = date.syncStatusLabel(relativeTo: now, calendar: calendar)
        XCTAssertTrue(result.contains("2025"), "Expected year in label, got: \(result)")
        XCTAssertTrue(result.hasPrefix("Synced"), "Expected 'Synced' prefix, got: \(result)")
    }

    // MARK: - 2+ calendar days ago, same year

    func testTwoDaysAgo_showsMonthDay_noYear() {
        // 2026-03-26 — two days before now (2026-03-28)
        var comps = DateComponents()
        comps.year = 2026; comps.month = 3; comps.day = 26
        comps.hour = 10; comps.timeZone = TimeZone(identifier: "UTC")
        let date = calendar.date(from: comps)!

        let result = date.syncStatusLabel(relativeTo: now, calendar: calendar)
        XCTAssertTrue(result.contains("Mar"), "Expected month in label, got: \(result)")
        XCTAssertFalse(result.contains("2026"), "Should not include year for same-year dates, got: \(result)")
    }

    // MARK: - Previous calendar day ("yesterday")

    func testYesterday_returnsYesterday() {
        // 2026-03-27 23:58 — yesterday by calendar, but only 2 minutes elapsed
        var comps = DateComponents()
        comps.year = 2026; comps.month = 3; comps.day = 27
        comps.hour = 23; comps.minute = 58; comps.timeZone = TimeZone(identifier: "UTC")
        let date = calendar.date(from: comps)!

        XCTAssertEqual(date.syncStatusLabel(relativeTo: now, calendar: calendar), "Synced yesterday",
                       "Calendar day should take priority over elapsed hours")
    }

    // MARK: - Same day, 0–59 seconds

    func testZeroSeconds_returnsJustNow() {
        XCTAssertEqual(now.syncStatusLabel(relativeTo: now, calendar: calendar), "Synced just now")
    }

    func test59Seconds_returnsJustNow() {
        let date = now.addingTimeInterval(-59)
        XCTAssertEqual(date.syncStatusLabel(relativeTo: now, calendar: calendar), "Synced just now")
    }

    // MARK: - Same day, 60–3599 seconds (minutes)

    func test60Seconds_returns1MinuteAgo() {
        let date = now.addingTimeInterval(-60)
        XCTAssertEqual(date.syncStatusLabel(relativeTo: now, calendar: calendar), "Synced 1 minute ago")
    }

    func test2Minutes_returns2MinutesAgo() {
        let date = now.addingTimeInterval(-120)
        XCTAssertEqual(date.syncStatusLabel(relativeTo: now, calendar: calendar), "Synced 2 minutes ago")
    }

    func test59Minutes_returns59MinutesAgo() {
        let date = now.addingTimeInterval(-59 * 60)
        XCTAssertEqual(date.syncStatusLabel(relativeTo: now, calendar: calendar), "Synced 59 minutes ago")
    }

    // MARK: - Same day, 3600+ seconds (hours)

    func test1Hour_returns1HourAgo() {
        let date = now.addingTimeInterval(-3600)
        XCTAssertEqual(date.syncStatusLabel(relativeTo: now, calendar: calendar), "Synced 1 hour ago")
    }

    func test2Hours_returns2HoursAgo() {
        let date = now.addingTimeInterval(-7200)
        XCTAssertEqual(date.syncStatusLabel(relativeTo: now, calendar: calendar), "Synced 2 hours ago")
    }

    func test3Hours_sameDayCheck() {
        // 2026-03-28 11:00 — 3 hours before now (14:00), same calendar day
        var comps = DateComponents()
        comps.year = 2026; comps.month = 3; comps.day = 28
        comps.hour = 11; comps.timeZone = TimeZone(identifier: "UTC")
        let date = calendar.date(from: comps)!

        XCTAssertEqual(date.syncStatusLabel(relativeTo: now, calendar: calendar), "Synced 3 hours ago")
    }

    /// Verifies that 22-23 hours elapsed on the same calendar day still shows "X hours ago"
    /// rather than "yesterday". This is the critical boundary: the calendar-day check must
    /// correctly identify both the sync and the reference time as the same day.
    func test22Hours_sameDayCalendarCheck() {
        // now = 2026-03-28 23:58, sync = 2026-03-28 00:30 — 23h28m elapsed, same calendar day
        var nowComps = DateComponents()
        nowComps.year = 2026; nowComps.month = 3; nowComps.day = 28
        nowComps.hour = 23; nowComps.minute = 58; nowComps.timeZone = TimeZone(identifier: "UTC")
        let lateNow = calendar.date(from: nowComps)!

        var syncComps = DateComponents()
        syncComps.year = 2026; syncComps.month = 3; syncComps.day = 28
        syncComps.hour = 0; syncComps.minute = 30; syncComps.timeZone = TimeZone(identifier: "UTC")
        let earlySync = calendar.date(from: syncComps)!

        // ~23 hours elapsed but both timestamps are on 2026-03-28 → must NOT show "yesterday"
        let result = earlySync.syncStatusLabel(relativeTo: lateNow, calendar: calendar)
        XCTAssertFalse(result.contains("yesterday"), "Same calendar day must not show 'yesterday', got: \(result)")
        XCTAssertTrue(result.contains("hours ago"), "Expected hours label for ~23h same-day elapsed, got: \(result)")
    }
}
