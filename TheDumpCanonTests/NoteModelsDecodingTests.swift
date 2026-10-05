import XCTest
@testable import The_Dump

/// A null inside sub_cat_names once failed the whole notes response and
/// blanked Browse ("Failed to decode response"). These fail if that returns.
final class NoteModelsDecodingTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    func testNoteListDropsNullSubCategoryNames() throws {
        let list = try decode(NoteListResponse.self, """
        {"notes": [{"organized_note_id": "n1", "title": "T", "preview": "p",
                    "note_content_modified": "2026-10-05T14:00:00Z",
                    "category_id": 7, "category_name": "Work",
                    "note_type": "Idea", "mime_type": "text",
                    "sub_cat_names": [null, "groceries"]}],
         "next_cursor_time": null, "next_cursor_id": null, "has_more": false}
        """)
        XCTAssertEqual(list.notes.first?.sub_cat_names, ["groceries"])
        XCTAssertEqual(list.notes.first?.category_id, 7)
    }

    func testMissingOrNullSubCategoryListStaysNil() throws {
        let missing = try decode(NotePreview.self, """
        {"organized_note_id": "n1", "preview": "p", "note_content_modified": "x"}
        """)
        XCTAssertNil(missing.sub_cat_names)
        let null = try decode(NotePreview.self, """
        {"organized_note_id": "n1", "preview": "p", "note_content_modified": "x", "sub_cat_names": null}
        """)
        XCTAssertNil(null.sub_cat_names)
    }

    func testFullNoteAndEditResponseDropNullSubCategoryNames() throws {
        let detail = try decode(NoteDetail.self, """
        {"organized_note_id": "n1", "note_content": "body", "note_content_modified": "x",
         "sub_cat_names": ["a", null], "tags": ["t"]}
        """)
        XCTAssertEqual(detail.sub_cat_names, ["a"])
        XCTAssertEqual(detail.tags, ["t"])

        let edited = try decode(EditNoteResponse.self, """
        {"success": true, "note": {"organized_note_id": "n1", "sub_cat_names": [null]}}
        """)
        XCTAssertEqual(edited.note?.sub_cat_names, [])
    }

    func testRequiredFieldsStillRequired() {
        XCTAssertThrowsError(try decode(NotePreview.self, """
        {"organized_note_id": "n1", "note_content_modified": "x"}
        """))
    }
}
