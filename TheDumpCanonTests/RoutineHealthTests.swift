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

        let older = try decode(RoutineDetailResponse.self, """
        {"routine_id": "r1", "slug": "a", "name": "A", "enabled": true, "documents": []}
        """)
        XCTAssertNil(older.status)
    }
}
