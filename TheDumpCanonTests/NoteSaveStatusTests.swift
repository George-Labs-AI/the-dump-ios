import XCTest
@testable import The_Dump

/// What the note screen's top bar says while the title is edited in place:
/// "Title required" only while a changed title is blank.
@MainActor
final class NoteSaveStatusTests: XCTestCase {
    private typealias SaveState = NoteDetailViewModel.SaveState

    private func groceries() -> NoteEditDraft {
        NoteEditDraft(title: "Groceries", content: "Milk, eggs")
    }

    private func status(of draft: NoteEditDraft, from current: SaveState) -> SaveState {
        NoteDetailViewModel.saveState(afterTextChangeFrom: current, isTitleSaveable: draft.isTitleSaveable)
    }

    func testClearingTheTitleAsksForOne() {
        var draft = groceries()
        draft.title = ""
        for current: SaveState in [.idle, .saving, .saved, .failed, .titleRequired] {
            XCTAssertEqual(status(of: draft, from: current), .titleRequired, "\(current)")
        }
    }

    // Putting the old title back leaves nothing to save, so no save comes
    // along to replace the warning; the change itself has to clear it.
    func testPuttingTheTitleBackClearsTheWarning() {
        var draft = groceries()
        draft.title = ""
        let cleared = status(of: draft, from: .idle)
        draft.title = "Groceries"
        XCTAssertFalse(draft.titleChanged)
        XCTAssertEqual(status(of: draft, from: cleared), .idle)
    }

    func testTypingANewTitleClearsTheWarning() {
        var draft = groceries()
        draft.title = ""
        let cleared = status(of: draft, from: .saved)
        draft.title = "Groc"
        XCTAssertEqual(status(of: draft, from: cleared), .idle)
    }

    // The other statuses describe a save, so a keystroke leaves them for
    // the save to change.
    func testAChangeWithATitleLeavesOtherStatusesAlone() {
        var draft = groceries()
        draft.content = "Milk, eggs, bread"
        for current: SaveState in [.idle, .saving, .saved, .failed] {
            XCTAssertEqual(status(of: draft, from: current), current, "\(current)")
        }
    }

    // A note stored without a title can still have its body edited.
    func testANoteStoredWithoutATitleIsNotAskedForOne() {
        var draft = NoteEditDraft(title: "", content: "Milk")
        draft.content = "Milk, eggs"
        XCTAssertEqual(status(of: draft, from: .idle), .idle)
    }
}
