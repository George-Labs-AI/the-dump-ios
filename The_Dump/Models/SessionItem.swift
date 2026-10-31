import Foundation

enum SessionItemKind: String, Codable {
    case photo
    case audio
    case file
    case text
}

enum UploadStatus: Equatable {
    case pending
    case uploading
    case captured
    case failed(error: String)

    var displayText: String {
        switch self {
        case .pending:
            return "Pending…"
        case .uploading:
            return "Uploading…"
        case .captured:
            return "Captured!"
        case .failed(let error):
            return "Failed: \(error)"
        }
    }

    var isRetryable: Bool {
        if case .failed = self { return true }
        return false
    }
}

struct SessionItem: Identifiable {
    let id: String
    let createdAt: Date
    let kind: SessionItemKind
    let originalFilename: String
    var localFileURL: URL?
    var status: UploadStatus
    /// How much of the upload has been sent, from 0 to 1; nil until the
    /// first bytes go out.
    var progress: Double?

    init(
        id: String = UUID().uuidString,
        createdAt: Date = Date(),
        kind: SessionItemKind,
        originalFilename: String,
        localFileURL: URL? = nil,
        status: UploadStatus = .pending
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kind = kind
        self.originalFilename = originalFilename
        self.localFileURL = localFileURL
        self.status = status
    }
}
