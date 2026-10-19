import XCTest
@testable import The_Dump

/// When the note screen offers "View original": the web's rule, so both
/// platforms show the button for the same notes.
@MainActor
final class OriginalButtonRuleTests: XCTestCase {
    private func note(mime: String, hasAsset: Bool?, type: String = "Log") throws -> NoteDetail {
        let hasAssetJSON = hasAsset.map { ", \"has_asset\": \($0)" } ?? ""
        return try JSONDecoder().decode(NoteDetail.self, from: Data("""
        {"organized_note_id": "n1", "note_content": "b", "note_content_modified": "x",
         "mime_type": "\(mime)", "note_type": "\(type)"\(hasAssetJSON)}
        """.utf8))
    }

    func testShownForEveryKindTheServerSaysHasAFile() throws {
        for mime in ["image", "voice", "document", "text"] {
            XCTAssertTrue(NoteDetailViewModel.showsOriginalButton(for: try note(mime: mime, hasAsset: true)), mime)
        }
    }

    func testHiddenWhenTheServerSaysThereIsNoFile() throws {
        for mime in ["image", "voice", "document", "text"] {
            XCTAssertFalse(NoteDetailViewModel.showsOriginalButton(for: try note(mime: mime, hasAsset: false)), mime)
        }
        XCTAssertFalse(NoteDetailViewModel.showsOriginalButton(for: nil))
    }

    func testOlderServersFallBackToPhotosAndRecordings() throws {
        XCTAssertTrue(NoteDetailViewModel.showsOriginalButton(for: try note(mime: "image", hasAsset: nil)))
        XCTAssertTrue(NoteDetailViewModel.showsOriginalButton(for: try note(mime: "voice", hasAsset: nil)))
        XCTAssertFalse(NoteDetailViewModel.showsOriginalButton(for: try note(mime: "text", hasAsset: nil)))
        XCTAssertFalse(NoteDetailViewModel.showsOriginalButton(for: try note(mime: "document", hasAsset: nil)))
    }

    func testIconMatchesTheWebsKinds() throws {
        XCTAssertEqual(NoteDetailViewModel.originalButtonIcon(for: try note(mime: "image", hasAsset: true)), "photo.on.rectangle")
        XCTAssertEqual(NoteDetailViewModel.originalButtonIcon(for: try note(mime: "voice", hasAsset: true)), "waveform")
        XCTAssertEqual(NoteDetailViewModel.originalButtonIcon(for: try note(mime: "document", hasAsset: true)), "doc")
        XCTAssertEqual(NoteDetailViewModel.originalButtonIcon(for: try note(mime: "text", hasAsset: true)), "paperclip")
    }

    // The server stores real media types for some files and bare extensions
    // for others; both get the web's icon.
    func testIconReadsRealMediaTypesAndBareExtensions() throws {
        let expected: [String: String] = [
            "image/jpeg": "photo.on.rectangle", "heic": "photo.on.rectangle", "PNG": "photo.on.rectangle",
            "audio/mp4": "waveform", "m4a": "waveform", "wav": "waveform",
            "application/pdf": "doc", "pdf": "doc", "docx": "doc", "text/csv": "doc",
            "text/plain": "paperclip", "": "paperclip"
        ]
        for (mime, icon) in expected {
            XCTAssertEqual(NoteDetailViewModel.originalButtonIcon(for: try note(mime: mime, hasAsset: true)), icon, mime)
        }
    }

    func testFileKindMatchesTheWebsMapping() {
        XCTAssertEqual(OriginalFileKind(mimeType: "image/webp"), .image)
        XCTAssertEqual(OriginalFileKind(mimeType: "jpg"), .image)
        XCTAssertEqual(OriginalFileKind(mimeType: "audio/mpeg"), .voice)
        XCTAssertEqual(OriginalFileKind(mimeType: "application/vnd.ms-excel"), .document)
        XCTAssertEqual(OriginalFileKind(mimeType: "text/markdown"), .document)
        XCTAssertEqual(OriginalFileKind(mimeType: "text/plain"), .text)
        XCTAssertEqual(OriginalFileKind(mimeType: nil), .text)
    }
}
