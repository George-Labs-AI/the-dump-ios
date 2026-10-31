import XCTest
@testable import The_Dump

/// Raw markdown previews become the clean text the Dump and Category rows
/// show.
final class PlainTextPreviewTests: XCTestCase {
    /// The two shapes the file service writes for a photo: a description
    /// alone, or the text read from it followed by a quoted description.
    func testPhotoLabelIsDropped() {
        XCTAssertEqual(
            PlainTextPreview.text(from: "*Image (photo):* A close-up of a **whiteboard** with notes."),
            "A close-up of a whiteboard with notes."
        )
        XCTAssertEqual(
            PlainTextPreview.text(from: "Q4 goals\nShip iOS\n\n> *Image (handwriting):* A whiteboard with notes."),
            "Q4 goals Ship iOS A whiteboard with notes."
        )
        XCTAssertEqual(
            PlainTextPreview.text(from: "Agenda\n\n> *Document (slide deck):* A deck about Q4."),
            "Agenda A deck about Q4."
        )
    }

    func testSpacedRulesAreDropped() {
        XCTAssertEqual(PlainTextPreview.text(from: "Intro\n* * *\n- - -\n---\nMore"), "Intro More")
    }

    func testHeadingsListsAndLinesAreJoined() {
        let markdown = """
        # Hotel vending

        - Chargers and *toiletries*
        - 2. See [the deck](https://example.com/deck)
        """
        XCTAssertEqual(
            PlainTextPreview.text(from: markdown),
            "Hotel vending Chargers and toiletries 2. See the deck"
        )
    }

    func testPlainTextIsUnchanged() {
        XCTAssertEqual(PlainTextPreview.text(from: "Call Sam about the lease"), "Call Sam about the lease")
    }

    func testWordsWithUnderscoresAndAsterisksInsideAreKept() {
        XCTAssertEqual(PlainTextPreview.text(from: "file_name_v2 and 5*3=15"), "file_name_v2 and 5*3=15")
    }

    func testCodeAndTaskBoxes() {
        XCTAssertEqual(PlainTextPreview.text(from: "- [ ] run `make test`\n- [x] ship"), "run make test ship")
    }
}
