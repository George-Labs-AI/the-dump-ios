import Foundation

/// How a note list labels time (Paper, 03 Category): notes sit under "Today",
/// "This week", then one label per month, and each row shows a short time or
/// day on the right.
nonisolated enum NoteListDates {
    /// The group a note falls in. Lists are newest first, so groups come out
    /// in order.
    static func groupLabel(for date: Date?, now: Date = Date(), calendar: Calendar = .current) -> String {
        guard let date else { return "Earlier" }
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) { return "This week" }
        let format = calendar.isDate(date, equalTo: now, toGranularity: .year) ? "MMMM" : "MMMM yyyy"
        return formatter(format, calendar: calendar).string(from: date)
    }

    /// The time for today's notes, the weekday for this week's, then the
    /// date (with the year once it isn't this year).
    static func shortLabel(for date: Date?, now: Date = Date(), calendar: Calendar = .current) -> String? {
        guard let date else { return nil }
        if calendar.isDate(date, inSameDayAs: now) {
            let time = DateFormatter()
            time.calendar = calendar
            time.timeZone = calendar.timeZone
            time.locale = calendar.locale ?? .current
            time.dateStyle = .none
            time.timeStyle = .short
            return time.string(from: date)
        }
        if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            return formatter("EEE", calendar: calendar).string(from: date)
        }
        let format = calendar.isDate(date, equalTo: now, toGranularity: .year) ? "MMM d" : "MMM d, yyyy"
        return formatter(format, calendar: calendar).string(from: date)
    }

    private static func formatter(_ template: String, calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale ?? .current
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }
}
