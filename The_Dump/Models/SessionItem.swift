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
    case processing
    case processed(noteId: String, title: String?, category: String?)
    case failed(error: String)
    
    var displayText: String {
        switch self {
        case .pending:
            return "Pending…"
        case .uploading:
            return "Uploading…"
        case .processing:
            return "Processing…"
        case .processed(_, _, let category):
            if let category, !category.isEmpty {
                return "Organized → \(category)"
            }
            return "Organized"
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
    var thumbnailData: Data?
    var fileUuid: String?
    
    init(
        id: String = UUID().uuidString,
        createdAt: Date = Date(),
        kind: SessionItemKind,
        originalFilename: String,
        localFileURL: URL? = nil,
        status: UploadStatus = .pending,
        thumbnailData: Data? = nil,
        fileUuid: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kind = kind
        self.originalFilename = originalFilename
        self.localFileURL = localFileURL
        self.status = status
        self.thumbnailData = thumbnailData
        self.fileUuid = fileUuid
    }
}
