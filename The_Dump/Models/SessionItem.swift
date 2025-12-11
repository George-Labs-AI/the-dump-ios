import Foundation

enum SessionItemKind: String, Codable {
    case photo
    case audio
}

enum UploadStatus: Equatable {
    case pending
    case uploading
    case success(storagePath: String)
    case failed(error: String)
    
    var displayText: String {
        switch self {
        case .pending:
            return "Pending…"
        case .uploading:
            return "Uploading…"
        case .success(let path):
            return "Uploaded to \(path)"
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
    var thumbnailData: Data? // For photos
    
    init(
        id: String = UUID().uuidString,
        createdAt: Date = Date(),
        kind: SessionItemKind,
        originalFilename: String,
        localFileURL: URL? = nil,
        status: UploadStatus = .pending,
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kind = kind
        self.originalFilename = originalFilename
        self.localFileURL = localFileURL
        self.status = status
        self.thumbnailData = thumbnailData
    }
}
