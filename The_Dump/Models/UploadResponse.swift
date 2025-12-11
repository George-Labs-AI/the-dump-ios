import Foundation
import Combine

struct UploadResponse: Codable {
    let uploadUrl: String
    let storagePath: String
    let originalFilename: String
    let metadata: UploadMetadata
    let uuid: String
    let isQuickNote: Bool
}

struct UploadMetadata: Codable {
    let userEmail: String
    let uploadTime: String
    let originalFilename: String
    let fileExtension: String
    let fileUuid: String
    let isQuickNote: String
    
    enum CodingKeys: String, CodingKey {
        case userEmail = "user_email"
        case uploadTime = "upload_time"
        case originalFilename = "original_filename"
        case fileExtension = "file_extension"
        case fileUuid = "file_uuid"
        case isQuickNote = "is_quick_note"
    }
}

struct APIErrorResponse: Codable {
    let error: String
}
