import XCTest
@testable import The_Dump

/// What the note screen reads from /api/pull_full_notes beyond the basics:
/// has_asset (drives "View original") and the modified date, which this
/// endpoint sends as an HTTP date rather than ISO-8601.
@MainActor
final class NoteDetailDecodingTests: XCTestCase {
    private func decodeNote(_ json: String) throws -> NoteDetail {
        try JSONDecoder().decode(NoteDetail.self, from: Data(json.utf8))
    }

    func testHasAssetPresentFalseOrMissing() throws {
        let response = try JSONDecoder().decode(NoteDetailResponse.self, from: Data("""
        {"notes": [{"author": null, "category_id": 217, "category_name": "Personal",
                    "has_asset": true, "mime_type": "document",
                    "note_content": "# Heading", "note_content_modified": "Fri, 16 Oct 2026 02:40:13 GMT",
                    "note_type": "Reference", "organized_note_id": "n1",
                    "sub_cat_names": [], "title": "Saved bookmark"}]}
        """.utf8))
        XCTAssertEqual(response.notes.first?.has_asset, true)

        let without = try decodeNote("""
        {"organized_note_id": "n2", "note_content": "b", "note_content_modified": "x", "has_asset": false}
        """)
        XCTAssertEqual(without.has_asset, false)

        // Older servers didn't send it.
        let older = try decodeNote("""
        {"organized_note_id": "n3", "note_content": "b", "note_content_modified": "x"}
        """)
        XCTAssertNil(older.has_asset)
    }

    func testNoteDatesReadEveryFormTheServerSends() throws {
        let expected = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-19T03:14:35Z"))

        // /api/pull_notes
        XCTAssertEqual(NoteDates.parse("2026-10-19T03:14:35.634209Z").map { floor($0.timeIntervalSince1970) },
                       expected.timeIntervalSince1970)
        XCTAssertEqual(NoteDates.parse("2026-10-19T03:14:35Z"), expected)
        // The edit response's isoformat(), with and without a zone.
        XCTAssertEqual(NoteDates.parse("2026-10-19T03:14:35.634209+00:00").map { floor($0.timeIntervalSince1970) },
                       expected.timeIntervalSince1970)
        XCTAssertEqual(NoteDates.parse("2026-10-19T03:14:35.634209"), expected)
        // /api/pull_full_notes
        XCTAssertEqual(NoteDates.parse("Mon, 19 Oct 2026 03:14:35 GMT"), expected)

        XCTAssertNil(NoteDates.parse(""))
        XCTAssertNil(NoteDates.parse(nil))
        XCTAssertNil(NoteDates.parse("yesterday"))
    }
}
