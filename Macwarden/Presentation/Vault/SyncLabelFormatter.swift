import Foundation

// MARK: - Sync label formatter

extension Optional where Wrapped == Date {
    /// Returns a human-friendly relative sync status label for display in the sidebar footer.
    ///
    /// Returns `"Never synced"` when the date is `nil`.
    /// See `Date.syncStatusLabel(relativeTo:calendar:)` for label tier documentation.
    func syncStatusLabel(
        relativeTo now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        switch self {
        case .none:       return "Never synced"
        case .some(let d): return d.syncStatusLabel(relativeTo: now, calendar: calendar)
        }
    }
}

extension Date {
    /// Returns a human-friendly relative label for this date relative to `now`.
    ///
    /// Tiers are evaluated in this order (calendar day first, then elapsed time):
    ///
    /// **Calendar day checks (evaluated first):**
    /// 1. Future timestamp → "Synced just now" (clock skew guard)
    /// 2. Previous calendar year or earlier → "Synced Month Day, Year" (e.g. "Synced Mar 26, 2025")
    /// 3. Two or more calendar days ago, same year → "Synced Month Day" (e.g. "Synced Mar 26")
    /// 4. Previous calendar day → "Synced yesterday"
    ///
    /// **Elapsed time checks (same calendar day only):**
    /// 5. 0–59 seconds → "Synced just now"
    /// 6. 60–3599 seconds → "Synced 1 minute ago" / "Synced X minutes ago"
    /// 7. 3600+ seconds → "Synced 1 hour ago" / "Synced X hours ago"
    ///
    /// Calendar day comparisons use the provided `calendar` (defaulting to `.current`)
    /// so the "yesterday" boundary respects the user's local timezone.
    func syncStatusLabel(
        relativeTo now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        // Tier 1: future timestamp — clamp to "just now" (clock skew guard)
        guard self <= now else { return "Synced just now" }

        let daysDiff = calendar.dateComponents([.day], from: self, to: now).day ?? 0
        let selfYear = calendar.component(.year, from: self)
        let nowYear  = calendar.component(.year, from: now)

        // Tier 2: previous calendar year
        if selfYear < nowYear {
            return "Synced \(formatted(style: .dateTime.month(.abbreviated).day().year(), calendar: calendar))"
        }

        // Tier 3: 2+ calendar days ago, same year
        if daysDiff >= 2 {
            return "Synced \(formatted(style: .dateTime.month(.abbreviated).day(), calendar: calendar))"
        }

        // Tier 4: previous calendar day ("yesterday")
        // Uses calendar day comparison rather than a fixed 24-hour window, so the boundary
        // always falls at midnight in the user's local timezone.
        if daysDiff == 1 {
            return "Synced yesterday"
        }

        // Same calendar day — use elapsed seconds for tiers 5–7.
        let elapsed = Int(now.timeIntervalSince(self))

        // Tier 5: 0–59 seconds
        if elapsed < 60 { return "Synced just now" }

        // Tier 6: 60–3599 seconds (minutes)
        if elapsed < 3600 {
            let minutes = elapsed / 60
            return minutes == 1 ? "Synced 1 minute ago" : "Synced \(minutes) minutes ago"
        }

        // Tier 7: 3600+ seconds (hours)
        let hours = elapsed / 3600
        return hours == 1 ? "Synced 1 hour ago" : "Synced \(hours) hours ago"
    }

    // MARK: - Private formatting helpers

    private func formatted(style: Date.FormatStyle, calendar: Calendar) -> String {
        // Date.FormatStyle is zero-allocation — no DateFormatter constructed per call.
        // Available macOS 12+; the project targets macOS 26.
        // Property assignment is required: FormatStyle exposes `calendar` as a stored var,
        // so chaining `.calendar(x)` is parsed as calling the Calendar value as a function.
        var s = style
        s.calendar = calendar
        s.locale   = calendar.locale ?? .current
        return self.formatted(s)
    }
}
