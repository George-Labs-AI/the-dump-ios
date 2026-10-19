import XCTest
@testable import The_Dump

/// The capture screen's Processing rows must use the web's words:
/// Uploading… / Processing… / Organizing… / Organized → {Category} /
/// Couldn't organize.
final class ProcessingStatusTextTests: XCTestCase {

    private func record(
        _ status: PendingNoteLifecycleStatus,
        categoryName: String? = nil,
        organizedNoteId: String? = nil,
        errorMessage: String? = nil
    ) -> PendingNoteRecord {
        PendingNoteRecord(
            fileUuid: "uuid-1",
            storagePath: "uploads/u/uuid-1.jpg",
            kind: .photo,
            lifecycleStatus: status,
            organizedNoteId: organizedNoteId,
            categoryName: categoryName,
            errorMessage: errorMessage
        )
    }

    func testEachServerStepHasTheWebsWords() {
        XCTAssertEqual(ProcessingStatusText.text(for: record(.uploaded)), "Processing…")
        XCTAssertEqual(ProcessingStatusText.text(for: record(.transcribed)), "Organizing…")
        XCTAssertEqual(ProcessingStatusText.text(for: record(.organized, categoryName: "Work")), "Organized → Work")
        XCTAssertEqual(ProcessingStatusText.text(for: record(.failed)), "Couldn't organize")
    }

    func testOrganizedWithoutACategoryJustSaysOrganized() {
        XCTAssertEqual(ProcessingStatusText.text(for: record(.organized)), "Organized")
        XCTAssertEqual(ProcessingStatusText.text(for: record(.organized, categoryName: "")), "Organized")
    }

    /// The server sends `error: "Processing failed"` for every failed note;
    /// that used to be shown as-is.
    func testFailedNoteIgnoresTheServersErrorText() {
        XCTAssertEqual(
            ProcessingStatusText.text(for: record(.failed, errorMessage: "Processing failed")),
            "Couldn't organize"
        )
    }

    func testUploadsSayUploadingAndKeepTheirOwnError() {
        XCTAssertEqual(ProcessingStatusText.text(for: UploadStatus.uploading), "Uploading…")
        XCTAssertEqual(ProcessingStatusText.text(for: UploadStatus.pending), "Uploading…")
        XCTAssertEqual(
            ProcessingStatusText.text(for: UploadStatus.failed(error: "File exceeds 100MB limit")),
            "File exceeds 100MB limit"
        )
    }

    func testOnlyOrganizedRowsWithANoteIdOpenANote() {
        XCTAssertEqual(record(.organized, organizedNoteId: "note-9").openableNoteId, "note-9")
        XCTAssertNil(record(.organized).openableNoteId)
        XCTAssertNil(record(.organized, organizedNoteId: "").openableNoteId)
        XCTAssertNil(record(.transcribed, organizedNoteId: "note-9").openableNoteId)
        XCTAssertNil(record(.failed, organizedNoteId: "note-9").openableNoteId)
    }
}
