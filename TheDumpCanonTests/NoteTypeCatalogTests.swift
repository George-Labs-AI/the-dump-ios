import XCTest
@testable import The_Dump

/// GET /api/note_types doesn't exist on older servers, so every failure must
/// leave the pickers showing the built-in list.
@MainActor
final class NoteTypeCatalogTests: XCTestCase {
    private struct Failure: Error {}

    func testBuiltInListMatchesServerNoteTypes() {
        // Same spelling and order as NOTE_TYPES in the web server's
        // helpers/normalization_helpers.py.
        XCTAssertEqual(NoteTypeCatalog.builtIn, [
            "Scratch Capture", "To-Do", "Checklist", "Shopping List", "Media List",
            "Recipe", "Contact", "Resume", "Schedule", "Reference", "Log",
            "Reflection", "Inspiration", "Reminder", "Brainstorm", "Content Idea", "Draft"
        ])
        XCTAssertEqual(NoteTypeCatalog.builtIn.count, 17)
    }

    // async on purpose: releasing a main-actor object at the end of a
    // synchronous XCTest method aborts inside the Swift runtime
    // (swift_task_deinitOnExecutorImpl, Xcode 26). Inside a task it's fine.
    func testStartsWithBuiltInList() async {
        let catalog = NoteTypeCatalog(fetch: { throw Failure() })
        XCTAssertEqual(catalog.types, NoteTypeCatalog.builtIn)
    }

    func testFailedFetchKeepsBuiltInList() async {
        let catalog = NoteTypeCatalog(fetch: { throw APIError.httpError(statusCode: 404, message: "Not Found") })
        await catalog.refresh()
        XCTAssertEqual(catalog.types, NoteTypeCatalog.builtIn)
    }

    func testEmptyOrBlankListKeepsBuiltInList() async {
        let empty = NoteTypeCatalog(fetch: { [] })
        await empty.refresh()
        XCTAssertEqual(empty.types, NoteTypeCatalog.builtIn)

        let blank = NoteTypeCatalog(fetch: { ["", "  "] })
        await blank.refresh()
        XCTAssertEqual(blank.types, NoteTypeCatalog.builtIn)
    }

    func testServerListReplacesBuiltInAndIsCached() async {
        var calls = 0
        let catalog = NoteTypeCatalog(fetch: {
            calls += 1
            return ["Recipe", " Draft ", "", "Recipe", "New Type"]
        })
        await catalog.refresh()
        XCTAssertEqual(catalog.types, ["Recipe", "Draft", "New Type"])

        await catalog.refresh()
        XCTAssertEqual(calls, 1, "a list from the server is kept for the rest of the run")
    }

    func testRetriesAfterFailure() async {
        var calls = 0
        let catalog = NoteTypeCatalog(fetch: {
            calls += 1
            if calls == 1 { throw Failure() }
            return ["Draft"]
        })
        await catalog.refresh()
        XCTAssertEqual(catalog.types, NoteTypeCatalog.builtIn)
        await catalog.refresh()
        XCTAssertEqual(catalog.types, ["Draft"])
    }

    func testDecodesNoteTypesResponse() throws {
        let decoded = try JSONDecoder().decode(NoteTypesResponse.self, from: Data("""
        {"note_types": ["Scratch Capture", "To-Do"]}
        """.utf8))
        XCTAssertEqual(decoded.note_types, ["Scratch Capture", "To-Do"])
    }

    func testRejectsBodyWithoutNoteTypes() {
        // A body of another shape fails to decode, which fetchNoteTypes()
        // turns into an error and the catalog then ignores.
        XCTAssertThrowsError(try JSONDecoder().decode(NoteTypesResponse.self, from: Data("""
        {"error": "Not found"}
        """.utf8)))
    }
}
