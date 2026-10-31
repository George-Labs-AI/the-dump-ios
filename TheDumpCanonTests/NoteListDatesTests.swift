import XCTest
@testable import The_Dump

/// The date groups and short dates on a note list (Paper, 03 Category).
final class NoteListDatesTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .current
        calendar.locale = Locale(identifier: "en_US")
        calendar.firstWeekday = 2
        return calendar
    }

    /// Thursday 30 October 2026, 3pm in New York.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 15)) ?? Date()
    }

    private func date(_ month: Int, _ day: Int, year: Int = 2026, hour: Int = 9, minute: Int = 12) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))
    }

    func testGroups() {
        XCTAssertEqual(NoteListDates.groupLabel(for: date(10, 30), now: now, calendar: calendar), "Today")
        XCTAssertEqual(NoteListDates.groupLabel(for: date(10, 27), now: now, calendar: calendar), "This week")
        XCTAssertEqual(NoteListDates.groupLabel(for: date(10, 3), now: now, calendar: calendar), "October")
        XCTAssertEqual(NoteListDates.groupLabel(for: date(12, 24, year: 2025), now: now, calendar: calendar), "December 2025")
        XCTAssertEqual(NoteListDates.groupLabel(for: nil, now: now, calendar: calendar), "Earlier")
    }

    func testShortLabels() {
        XCTAssertEqual(NoteListDates.shortLabel(for: date(10, 30), now: now, calendar: calendar), "9:12\u{202F}AM")
        XCTAssertEqual(NoteListDates.shortLabel(for: date(10, 27), now: now, calendar: calendar), "Tue")
        XCTAssertEqual(NoteListDates.shortLabel(for: date(10, 3), now: now, calendar: calendar), "Oct 3")
        XCTAssertEqual(NoteListDates.shortLabel(for: date(12, 24, year: 2025), now: now, calendar: calendar), "Dec 24, 2025")
        XCTAssertNil(NoteListDates.shortLabel(for: nil, now: now, calendar: calendar))
    }
}
