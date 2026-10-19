import XCTest
@testable import The_Dump

/// Stacks and the select-mode bulk actions. The JSON here is shaped like the
/// web server's replies.
@MainActor
final class StacksAndBulkActionsTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    private func jsonObject(_ data: Data?) throws -> [String: Any] {
        let data = try XCTUnwrap(data)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: Decoding stack rows

    // A list fetched with stacks=1: one row stands for a stack, a loose note
    // has stack_id null, stack_size 1 and stack_total null, and an older
    // server (or a search) sends no stack fields at all.
    func testStacksListRows() async throws {
        let list = try decode(NoteListResponse.self, """
        {"notes": [
            {"organized_note_id": "n1", "title": "T", "preview": "p", "note_content_modified": "x",
             "stack_id": "427dde7a-f8e9-4820-b7a4-f3e020f0b440",
             "stack_key": "427dde7a-f8e9-4820-b7a4-f3e020f0b440",
             "stack_size": 2, "stack_total": 2, "stack_time": "x", "has_asset": true},
            {"organized_note_id": "n2", "preview": "p", "note_content_modified": "x",
             "stack_id": null, "stack_key": "n2", "stack_size": 1, "stack_total": null},
            {"organized_note_id": "n3", "preview": "p", "note_content_modified": "x"}
         ],
         "next_cursor_time": "x", "next_cursor_id": "427dde7a-f8e9-4820-b7a4-f3e020f0b440", "has_more": false}
        """)
        XCTAssertEqual(list.notes.map(\.isStack), [true, false, false])
        XCTAssertEqual(list.notes.map(\.stackLabel), ["2 notes", nil, nil])
        XCTAssertEqual(list.notes[0].stack_id, "427dde7a-f8e9-4820-b7a4-f3e020f0b440")
        XCTAssertNil(list.notes[2].stack_size)
    }

    func testFilteredStackSaysHowManyMatch() async throws {
        let row = try decode(NotePreview.self, """
        {"organized_note_id": "n1", "preview": "p", "note_content_modified": "x",
         "stack_id": "s1", "stack_size": 2, "stack_total": 5}
        """)
        XCTAssertTrue(row.isStack)
        XCTAssertEqual(row.stackLabel, "2 of 5 notes")

        // One matching member of a bigger stack is still shown as the stack.
        let one = try decode(NotePreview.self, """
        {"organized_note_id": "n1", "preview": "p", "note_content_modified": "x",
         "stack_id": "s1", "stack_size": 1, "stack_total": 3}
        """)
        XCTAssertEqual(one.stackLabel, "1 of 3 notes")
    }

    // A note deleted from its own screen leaves the lists, except a row that
    // stands for a stack: the stack still holds its other notes.
    func testDeletedNoteLeavesTheListButAStackRowStays() async throws {
        let list = try decode(NoteListResponse.self, """
        {"notes": [
            {"organized_note_id": "n1", "preview": "p", "note_content_modified": "x",
             "stack_id": "s1", "stack_size": 3, "stack_total": 3},
            {"organized_note_id": "n2", "preview": "p", "note_content_modified": "x"},
            {"organized_note_id": "n3", "preview": "p", "note_content_modified": "x"}
         ],
         "has_more": false}
        """)
        XCTAssertEqual(list.notes.removingDeletedNote("n2").map(\.id), ["n1", "n3"])
        XCTAssertEqual(list.notes.removingDeletedNote("n1").map(\.id), ["n1", "n2", "n3"])
        XCTAssertEqual(list.notes.removingDeletedNote("elsewhere").map(\.id), ["n1", "n2", "n3"])

        // Only the note a stack row stands for makes the list reload.
        XCTAssertTrue(list.notes.hasStackRow(standingFor: "n1"))
        XCTAssertFalse(list.notes.hasStackRow(standingFor: "n2"))
        XCTAssertFalse(list.notes.hasStackRow(standingFor: "elsewhere"))
    }

    // A stack row keeps its identity when its newest note changes, so a stack
    // screen opened from it stays open when the list reloads.
    func testStackRowIsIdentifiedByItsStack() async throws {
        let before = try decode(NotePreview.self, """
        {"organized_note_id": "n1", "preview": "p", "note_content_modified": "x",
         "stack_id": "s1", "stack_size": 3, "stack_total": 3}
        """)
        let after = try decode(NotePreview.self, """
        {"organized_note_id": "n2", "preview": "p", "note_content_modified": "x",
         "stack_id": "s1", "stack_size": 2, "stack_total": 2}
        """)
        XCTAssertEqual(before.listRowID, after.listRowID)
        XCTAssertNotEqual(before.listRowID, "s1")

        // Plain notes, and a stack's members listed on their own, use the note id.
        let member = try decode(NotePreview.self, """
        {"organized_note_id": "n2", "preview": "p", "note_content_modified": "x", "stack_id": "s1"}
        """)
        XCTAssertEqual(member.listRowID, "n2")
    }

    // Members from /api/stack/<id> carry stack_id but no counts: plain notes.
    func testStackResponseMembersAreNotStacks() async throws {
        let response = try decode(StackResponse.self, """
        {"stack": {"stack_id": "427dde7a-f8e9-4820-b7a4-f3e020f0b440", "title": null,
                   "origin": "manual", "source_metadata": {"anything": [1, 2]},
                   "created_at": "2026-10-19T03:37:00Z"},
         "notes": [
            {"author": null, "category_id": 216, "category_name": "Work", "has_asset": true,
             "mime_type": "text", "note_content_modified": "2026-10-19T03:36:53Z", "note_type": null,
             "organized_note_id": "a1", "preview": "p",
             "stack_id": "427dde7a-f8e9-4820-b7a4-f3e020f0b440", "sub_cat_names": [], "title": "One"},
            {"organized_note_id": "a2", "preview": "p", "note_content_modified": "x",
             "stack_id": "427dde7a-f8e9-4820-b7a4-f3e020f0b440"}
         ]}
        """)
        XCTAssertNil(response.stack.title)
        XCTAssertEqual(response.stack.stackId, "427dde7a-f8e9-4820-b7a4-f3e020f0b440")
        XCTAssertEqual(response.notes.count, 2)
        XCTAssertEqual(response.notes.map(\.isStack), [false, false])
    }

    // failed_ids is left undecoded on purpose: after a bulk action the app
    // reloads the list rather than reading it.
    func testActionResponsesDecode() async throws {
        let stacked = try decode(StackNotesResponse.self, """
        {"message": "Stacked 2 notes.", "stack_id": "s1", "stacked_count": 2}
        """)
        XCTAssertEqual(stacked.stackId, "s1")
        XCTAssertEqual(stacked.stackedCount, 2)

        let deleted = try decode(BulkDeleteNotesResponse.self, """
        {"deleted_count": 3, "failed_ids": ["a", "b", "c"], "message": "Successfully deleted 3 notes."}
        """)
        XCTAssertEqual(deleted.deletedCount, 3)

        let updated = try decode(BulkUpdateNotesResponse.self, """
        {"failed_ids": ["a"], "message": "Successfully updated 3 notes.", "updated_count": 3}
        """)
        XCTAssertEqual(updated.updatedCount, 3)
    }

    // MARK: Request bodies

    func testStackAndUnstackBodies() async throws {
        let stack = try jsonObject(NotesActionRequest.body(StackNotesRequest(noteIds: ["a", "b"])))
        XCTAssertEqual(stack.keys.sorted(), ["note_ids"])
        XCTAssertEqual(stack["note_ids"] as? [String], ["a", "b"])

        let unstack = try jsonObject(NotesActionRequest.body(UnstackNotesRequest(stackId: "s1")))
        XCTAssertEqual(unstack.keys.sorted(), ["stack_id"])
        XCTAssertEqual(unstack["stack_id"] as? String, "s1")

        let delete = try jsonObject(NotesActionRequest.body(BulkDeleteNotesRequest(noteIds: ["a"])))
        XCTAssertEqual(delete.keys.sorted(), ["note_ids"])
    }

    // The server reads a missing key as "leave unchanged", so a category move
    // must not send a type and the other way round.
    func testBulkUpdateSendsOnlyTheChosenField() async throws {
        let move = try jsonObject(NotesActionRequest.body(
            BulkUpdateNotesRequest(noteIds: ["a", "b"], category: "Personal")
        ))
        XCTAssertEqual(move.keys.sorted(), ["category", "note_ids"])
        XCTAssertEqual(move["category"] as? String, "Personal")

        let retype = try jsonObject(NotesActionRequest.body(
            BulkUpdateNotesRequest(noteIds: ["a"], type: "Shopping List")
        ))
        XCTAssertEqual(retype.keys.sorted(), ["note_ids", "type"])
        XCTAssertEqual(retype["type"] as? String, "Shopping List")
    }

    func testRequestHeadersAndMethod() async throws {
        let body = try NotesActionRequest.body(BulkDeleteNotesRequest(noteIds: ["a"]))
        let post = try XCTUnwrap(NotesActionRequest.make(
            baseURL: "https://example.com", path: "/bulk_delete_notes", method: "POST", token: "tok", body: body
        ))
        XCTAssertEqual(post.url?.absoluteString, "https://example.com/bulk_delete_notes")
        XCTAssertEqual(post.httpMethod, "POST")
        XCTAssertEqual(post.value(forHTTPHeaderField: "Authorization"), "Bearer tok")
        XCTAssertEqual(post.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(post.httpBody, body)

        let get = try XCTUnwrap(NotesActionRequest.make(
            baseURL: "https://example.com", path: "/api/stack/s1", method: "GET", token: "tok", body: nil
        ))
        XCTAssertEqual(get.httpMethod, "GET")
        XCTAssertNil(get.httpBody)
        XCTAssertNil(get.value(forHTTPHeaderField: "Content-Type"))
    }

    func testStackIdMustBeAUUID() async {
        XCTAssertEqual(
            NotesActionRequest.validStackId(" 427DDE7A-F8E9-4820-B7A4-F3E020F0B440 "),
            "427dde7a-f8e9-4820-b7a4-f3e020f0b440"
        )
        for bad in ["", "not-a-uuid", "../bulk_delete_notes", "427dde7a-f8e9-4820-b7a4"] {
            XCTAssertNil(NotesActionRequest.validStackId(bad), bad)
        }
    }

    // The stack and bulk routes explain failures under "message".
    func testErrorsReadMessageThenError() async {
        let tooFew = NotesActionRequest.error(statusCode: 400, data: Data("""
        {"message": "At least 2 note IDs are required."}
        """.utf8))
        XCTAssertEqual(tooFew.errorDescription, "Bad request: At least 2 note IDs are required.")

        let missing = NotesActionRequest.error(statusCode: 404, data: Data("""
        {"error": "stack not found"}
        """.utf8))
        XCTAssertEqual(missing.errorDescription, "stack not found")
        if case .notFound = missing {} else { XCTFail("404 should be notFound") }

        let blank = NotesActionRequest.error(statusCode: 500, data: Data())
        XCTAssertEqual(blank.errorDescription, "Server error: Unknown error")
    }

    // MARK: Rows

    func testDisplayAuthorHidesBlankAndNull() async throws {
        let list = try decode(NoteListResponse.self, """
        {"notes": [{"organized_note_id": "n1", "preview": "p", "note_content_modified": "x",
                    "author": " Pat Sender <pat@example.com> "},
                   {"organized_note_id": "n2", "preview": "p", "note_content_modified": "x", "author": "   "},
                   {"organized_note_id": "n3", "preview": "p", "note_content_modified": "x", "author": null},
                   {"organized_note_id": "n4", "preview": "p", "note_content_modified": "x"}],
         "has_more": false}
        """)
        XCTAssertEqual(list.notes.map(\.displayAuthor), ["Pat Sender <pat@example.com>", nil, nil, nil])
    }

    // MARK: Delete confirmation

    func testDeleteNeedsTheExactCount() async {
        XCTAssertTrue(BulkDeleteConfirmation.matches(typed: "3", count: 3))
        XCTAssertTrue(BulkDeleteConfirmation.matches(typed: " 3 ", count: 3))
        XCTAssertTrue(BulkDeleteConfirmation.matches(typed: "12", count: 12))
        for typed in ["", "2", "03", "3 notes", "three", "3.0", "-3"] {
            XCTAssertFalse(BulkDeleteConfirmation.matches(typed: typed, count: 3), typed)
        }
        XCTAssertFalse(BulkDeleteConfirmation.matches(typed: "0", count: 0))
    }

    // MARK: Select mode

    func testSelectionSkipsStacksAndNeedsSelectMode() async throws {
        let note = try decode(NotePreview.self, """
        {"organized_note_id": "n1", "preview": "p", "note_content_modified": "x"}
        """)
        let stack = try decode(NotePreview.self, """
        {"organized_note_id": "n2", "preview": "p", "note_content_modified": "x",
         "stack_id": "s1", "stack_size": 2, "stack_total": 2}
        """)
        let viewModel = NotesListViewModel(filter: .all)

        viewModel.toggleSelection(note)
        XCTAssertTrue(viewModel.selectedNoteIDs.isEmpty, "nothing is picked outside select mode")

        viewModel.startSelecting()
        viewModel.toggleSelection(note)
        viewModel.toggleSelection(stack)
        XCTAssertEqual(viewModel.selectedNoteIDs, ["n1"])

        viewModel.toggleSelection(note)
        XCTAssertTrue(viewModel.selectedNoteIDs.isEmpty)

        viewModel.toggleSelection(note)
        viewModel.stopSelecting()
        XCTAssertFalse(viewModel.isSelecting)
        XCTAssertTrue(viewModel.selectedNoteIDs.isEmpty)
    }
}
