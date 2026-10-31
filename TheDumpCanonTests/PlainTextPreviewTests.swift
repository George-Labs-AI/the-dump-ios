import XCTest
@testable import The_Dump

/// Raw markdown previews become the clean text the Dump and Category rows
/// show.
final class PlainTextPreviewTests: XCTestCase {
    func testPhotoLabelAndQuoteAreDropped() {
        XCTAssertEqual(
            PlainTextPreview.text(from: "> *Image (photo):* A close-up of a **whiteboard** with notes."),
            "A close-up of a whiteboard with notes."
        )
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
