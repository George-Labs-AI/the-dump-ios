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

    // author (the sender of an emailed note) comes back on every note from
    // /api/pull_notes and /api/pull_full_notes, as null for the owner's own
    // notes; older servers left it out.
    func testNotePreviewAuthorPresentNullOrMissing() throws {
        let emailed = try decode(NoteListResponse.self, """
        {"notes": [{"organized_note_id": "n1", "preview": "p", "note_content_modified": "x",
                    "author": "Pat Sender <pat@example.com>"},
                   {"organized_note_id": "n2", "preview": "p", "note_content_modified": "x",
                    "author": null},
                   {"organized_note_id": "n3", "preview": "p", "note_content_modified": "x"}],
         "has_more": false}
        """)
        XCTAssertEqual(emailed.notes.map(\.author), ["Pat Sender <pat@example.com>", nil, nil])
    }

    func testNoteDetailAuthorPresentNullOrMissing() throws {
        let response = try decode(NoteDetailResponse.self, """
        {"notes": [{"organized_note_id": "n1", "note_content": "body", "note_content_modified": "x",
                    "author": "pat@example.com"},
                   {"organized_note_id": "n2", "note_content": "body", "note_content_modified": "x",
                    "author": null},
                   {"organized_note_id": "n3", "note_content": "body", "note_content_modified": "x"}]}
        """)
        XCTAssertEqual(response.notes.map(\.author), ["pat@example.com", nil, nil])
    }

    // onboarding_reset_allowed shows the Settings reset row for test
    // accounts; servers before THEDUMP-46 leave it out, which means no.
    func testNoteCountsOnboardingResetAllowedPresentOrMissing() throws {
        let allowed = try decode(NoteCountsResponse.self, """
        {"categories": {"Work": 2}, "onboarding_reset_allowed": true}
        """)
        XCTAssertTrue(allowed.isOnboardingResetAllowed)
        XCTAssertEqual(allowed.categoryCounts, ["Work": 2])

        let notAllowed = try decode(NoteCountsResponse.self, """
        {"categories": {}, "onboarding_reset_allowed": false}
        """)
        XCTAssertFalse(notAllowed.isOnboardingResetAllowed)

        let missing = try decode(NoteCountsResponse.self, """
        {"categories": {"Work": 2}}
        """)
        XCTAssertNil(missing.onboarding_reset_allowed)
        XCTAssertFalse(missing.isOnboardingResetAllowed)
    }

    func testRequiredFieldsStillRequired() {
        XCTAssertThrowsError(try decode(NotePreview.self, """
        {"organized_note_id": "n1", "note_content_modified": "x"}
        """))
    }
}
