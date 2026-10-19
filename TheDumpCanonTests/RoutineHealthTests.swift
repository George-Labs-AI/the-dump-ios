import XCTest
@testable import The_Dump

/// Routine health is shown in plain words from the `status.verdict` code the
/// server attaches to each routine. A missing, null or unknown code must
/// never fail decoding or put a raw code on screen.
final class RoutineHealthTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    func testEveryKnownCodeHasItsPlainWords() {
        let expected: [String: String] = [
            "OK": "Up to date",
            "NOTHING_TO_DO": "Nothing new",
            "PARTIAL": "Partly done",
            "UNKNOWN": "Waiting for first report",
            "FAILED": "Failed",
            "SILENT": "Not running",
            "PAUSED": "Paused",
        ]
        XCTAssertEqual(RoutineHealth.allCases.count, expected.count)
        for (code, words) in expected {
            XCTAssertEqual(RoutineHealth(status: RoutineStatus(verdict: code))?.label, words, code)
        }
    }

    // MARK: - Full label, worded like the web's status chip

    private let ended = "2026-10-18T12:00:00Z"
    private var endedDate: Date { ISO8601DateFormatter().date(from: ended)! }

    private func label(_ code: String, asOf: String? = nil, silentFor: Int? = nil,
                       after seconds: TimeInterval = 42 * 60) -> String? {
        RoutineHealth.displayText(for: RoutineStatus(verdict: code, asOf: asOf, silentForHours: silentFor),
                            now: endedDate.addingTimeInterval(seconds))
    }

    func testLabelAddsHowLongAgoTheLatestReportCameIn() {
        XCTAssertEqual(label("OK", asOf: ended), "Up to date · 42m ago")
        XCTAssertEqual(label("NOTHING_TO_DO", asOf: ended), "Nothing new · 42m ago")
        XCTAssertEqual(label("PARTIAL", asOf: ended), "Partly done · 42m ago")
        XCTAssertEqual(label("FAILED", asOf: ended), "Failed · 42m ago")
        XCTAssertEqual(label("OK", asOf: ended, after: 47 * 3600), "Up to date · 47h ago")
        XCTAssertEqual(label("OK", asOf: ended, after: 3 * 86400), "Up to date · 3d ago")
        XCTAssertEqual(label("OK", asOf: ended, after: -60), "Up to date · 0m ago")
    }

    func testUnknownIsWaitingOnlyWhenNoReportExists() {
        XCTAssertEqual(label("UNKNOWN"), "Waiting for first report")
        XCTAssertEqual(label("UNKNOWN", asOf: ""), "Waiting for first report")
        // A runner can report UNKNOWN itself; then a report does exist.
        XCTAssertEqual(label("UNKNOWN", asOf: ended), "Result unclear · 42m ago")
        XCTAssertEqual(label("UNKNOWN", asOf: ended, after: 3 * 3600), "Result unclear · 3h ago")
    }

    func testSilentAndPausedWording() {
        XCTAssertEqual(label("SILENT", asOf: ended, silentFor: 29), "Not running · no report for 29h")
        XCTAssertEqual(label("SILENT", silentFor: 3), "Not running · no reports yet")
        XCTAssertEqual(label("PAUSED", asOf: ended), "Paused")
        XCTAssertEqual(label("PAUSED"), "Paused")
    }

    func testReportTimesInOtherFormatsStillRead() {
        XCTAssertEqual(label("OK", asOf: "2026-10-18T11:59:59.876543Z"), "Up to date · 42m ago")
        // Partial minutes round down, as on the web.
        XCTAssertEqual(label("OK", asOf: "2026-10-18T12:00:00.123456Z"), "Up to date · 41m ago")
        XCTAssertEqual(label("OK", asOf: "2026-10-18T08:00:00-04:00"), "Up to date · 42m ago")
        // No time zone: read as UTC, as the server does.
        XCTAssertEqual(label("OK", asOf: "2026-10-18T12:00:00"), "Up to date · 42m ago")
        // Unreadable: just the words.
        XCTAssertEqual(label("OK", asOf: "yesterday"), "Up to date")
        XCTAssertEqual(label("UNKNOWN", asOf: "yesterday"), "Result unclear")
    }

    func testNoLabelWithoutAKnownCode() {
        XCTAssertNil(RoutineHealth.displayText(for: nil))
        XCTAssertNil(RoutineHealth.displayText(for: RoutineStatus(verdict: "NEW_CODE", asOf: ended)))
    }

    func testMissingOrUnknownCodeHasNoLabel() {
        XCTAssertNil(RoutineHealth(status: nil))
        XCTAssertNil(RoutineHealth(status: RoutineStatus(verdict: nil)))
        XCTAssertNil(RoutineHealth(status: RoutineStatus(verdict: "SOMETHING_NEW")))
        XCTAssertNil(RoutineHealth(status: RoutineStatus(verdict: "ok")))
        XCTAssertNil(RoutineHealth(status: RoutineStatus(verdict: "")))
    }

    func testListDecodesStatusInEveryShape() throws {
        let list = try decode(RoutinesListResponse.self, """
        {"routines": [
          {"routine_id": "r1", "slug": "a", "name": "A", "enabled": true,
           "status": {"verdict": "SILENT", "as_of": null, "reasons": [], "open_asks": 0,
                      "silent_for_hours": 30, "paused": false, "next_expected": "",
                      "email_sweep": null}},
          {"routine_id": "r2", "slug": "b", "name": "B", "enabled": true, "status": null},
          {"routine_id": "r3", "slug": "c", "name": "C", "enabled": true},
          {"routine_id": "r4", "slug": "d", "name": "D", "enabled": true, "status": {"verdict": "NEW_CODE"}},
          {"routine_id": "r5", "slug": "e", "name": "E", "enabled": true, "status": {"verdict": 7}},
          {"routine_id": "r6", "slug": "f", "name": "F", "enabled": true, "status": {}}
        ]}
        """)
        XCTAssertEqual(list.routines.count, 6)
        XCTAssertEqual(RoutineHealth(status: list.routines[0].status)?.label, "Not running")
        XCTAssertEqual(list.routines[0].status?.silentForHours, 30)
        XCTAssertNil(list.routines[0].status?.asOf)
        XCTAssertEqual(RoutineHealth.displayText(for: list.routines[0].status), "Not running · no reports yet")
        XCTAssertNil(list.routines[1].status)
        XCTAssertNil(list.routines[2].status)
        XCTAssertEqual(list.routines[3].status?.verdict, "NEW_CODE")
        XCTAssertNil(RoutineHealth(status: list.routines[3].status))
        XCTAssertNil(list.routines[4].status?.verdict)
        XCTAssertNil(list.routines[5].status?.verdict)
    }

    func testDetailDecodesStatus() throws {
        let detail = try decode(RoutineDetailResponse.self, """
        {"routine_id": "r1", "slug": "a", "name": "A", "enabled": true,
         "status": {"verdict": "PAUSED", "paused": true}, "documents": []}
        """)
        XCTAssertEqual(RoutineHealth(status: detail.status)?.label, "Paused")

        let reported = try decode(RoutineDetailResponse.self, """
        {"routine_id": "r1", "slug": "a", "name": "A", "enabled": true, "documents": [],
         "status": {"verdict": "UNKNOWN", "as_of": "2026-10-18T12:00:00Z", "silent_for_hours": "x"}}
        """)
        XCTAssertEqual(reported.status?.asOf, "2026-10-18T12:00:00Z")
        XCTAssertNil(reported.status?.silentForHours)
        XCTAssertEqual(RoutineHealth.displayText(for: reported.status, now: endedDate.addingTimeInterval(3600)),
                       "Result unclear · 1h ago")

        let older = try decode(RoutineDetailResponse.self, """
        {"routine_id": "r1", "slug": "a", "name": "A", "enabled": true, "documents": []}
        """)
        XCTAssertNil(older.status)
    }
}
