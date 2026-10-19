import Foundation

/// The words the capture screen's Processing rows show at each step. They
/// match the web's Processing list word for word, so a capture reads the
/// same on both platforms: Uploading… → Processing… → Organizing… →
/// Organized → {Category}, or Couldn't organize if the server gives up.
enum ProcessingStatusText {
    static let uploading = "Uploading…"
    static let processing = "Processing…"
    static let organizing = "Organizing…"
    static let couldNotOrganize = "Couldn't organize"

    static func organized(categoryName: String?) -> String {
        guard let categoryName, !categoryName.isEmpty else { return "Organized" }
        return "Organized → \(categoryName)"
    }

    /// Words for a capture the server has received. A failed note always
    /// says "Couldn't organize": the server's error text is the generic
    /// "Processing failed" for every failure, and the web doesn't show it
    /// either.
    static func text(for record: PendingNoteRecord) -> String {
        switch record.lifecycleStatus {
        case .uploaded:
            return processing
        case .transcribed:
            return organizing
        case .organized:
            return organized(categoryName: record.categoryName)
        case .failed:
            return couldNotOrganize
        }
    }

    /// Words for a capture still on its way to the server. A failed upload
    /// keeps its own error (for example the 100MB limit): the file never
    /// reached the server, so "Couldn't organize" would be wrong.
    static func text(for status: UploadStatus) -> String {
        switch status {
        case .pending, .uploading:
            return uploading
        case .captured:
            return "Captured!"
        case .failed(let error):
            return error
        }
    }
}

extension PendingNoteRecord {
    /// The note a tap on this row opens: only organized rows open anything,
    /// and only once the server has said which note the capture became.
    var openableNoteId: String? {
        guard lifecycleStatus == .organized,
              let organizedNoteId, !organizedNoteId.isEmpty else { return nil }
        return organizedNoteId
    }
}
