import Foundation
import UIKit
import Combine
import UniformTypeIdentifiers

class UploadService {
    static let shared = UploadService()
    
    private let backendBaseURL = "https://thedump.ai"
    private let uploadEndpoint = "/api/mobile/upload_file"
    
    private init() {}
    
    // MARK: - Photo Upload
    
    func uploadPhoto(
        image: UIImage,
        userEmail: String,
        idToken: String
    ) async throws -> UploadResponse {
        guard let jpegData = image.jpegData(compressionQuality: 0.85) else {
            throw APIError.encodingFailed
        }

        let filename = generateFilename(kind: "photo", extension: "jpg")

        return try await uploadData(
            data: jpegData,
            filename: filename,
            contentType: "image/jpeg",
            isQuickNote: false,
            idToken: idToken
        )
    }
    
    // MARK: - Audio Upload
    
    func uploadAudio(
        fileURL: URL,
        userEmail: String,
        idToken: String
    ) async throws -> UploadResponse {
        let audioData = try Data(contentsOf: fileURL)

        // Enforce 100MB size limit
        let maxSize = 100 * 1024 * 1024
        guard audioData.count <= maxSize else {
            throw APIError.badRequest(message: "File exceeds 100MB limit")
        }

        let filename = generateFilename(kind: "voice", extension: "m4a")

        return try await uploadData(
            data: audioData,
            filename: filename,
            contentType: "audio/m4a",
            isQuickNote: false,
            idToken: idToken
        )
    }

    // MARK: - File Upload

    func uploadFile(
        fileURL: URL,
        userEmail: String,
        idToken: String
    ) async throws -> UploadResponse {
        // Start security-scoped access for files from document picker
        let didStartAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileData = try Data(contentsOf: fileURL)

        // Enforce 100MB size limit
        let maxSize = 100 * 1024 * 1024
        guard fileData.count <= maxSize else {
            throw APIError.badRequest(message: "File exceeds 100MB limit")
        }

        let originalFilename = fileURL.lastPathComponent
        let ext = fileURL.pathExtension.lowercased()
        let contentType = mimeType(for: fileURL)

        // Preserve original extension in generated filename
        let filename = generateFilename(kind: "file", extension: ext.isEmpty ? "bin" : ext)

        return try await uploadData(
            data: fileData,
            filename: filename,
            contentType: contentType,
            isQuickNote: false,
            idToken: idToken
        )
    }

    // MARK: - Text Note Upload

    func uploadTextNote(
        content: String,
        idToken: String
    ) async throws -> UploadResponse {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.badRequest(message: "Note cannot be empty")
        }

        let data = Data(content.utf8)
        let filename = generateFilename(kind: "note", extension: "txt")

        return try await uploadData(
            data: data,
            filename: filename,
            contentType: "text/plain",
            isQuickNote: true,
            idToken: idToken
        )
    }

    // MARK: - Private Methods

    private func mimeType(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if let utType = UTType(filenameExtension: ext),
           let mime = utType.preferredMIMEType {
            return mime
        }
        return "application/octet-stream"
    }
    
    private func generateFilename(kind: String, extension ext: String) -> String {
        let uuid = UUID().uuidString.lowercased()
        return "\(kind)_\(uuid).\(ext)"
    }

    /// Generic upload method: requests signed URL then uploads data to GCS
    private func uploadData(
        data: Data,
        filename: String,
        contentType: String,
        isQuickNote: Bool = false,
        idToken: String
    ) async throws -> UploadResponse {
        // Get signed URL from backend
        let response = try await requestSignedURL(
            filename: filename,
            contentType: contentType,
            isQuickNote: isQuickNote,
            idToken: idToken
        )

        // Upload to GCS
        try await uploadToGCS(
            data: data,
            uploadURL: response.uploadUrl,
            contentType: contentType
        )

        return response
    }

    private func requestSignedURL(
        filename: String,
        contentType: String,
        isQuickNote: Bool = false,
        idToken: String
    ) async throws -> UploadResponse {
        guard let url = URL(string: backendBaseURL + uploadEndpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "filename": filename,
            "contentType": contentType,
            "isQuickNote": isQuickNote
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknownError
        }
        
        if httpResponse.statusCode != 200 {
            let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw APIError.from(statusCode: httpResponse.statusCode, errorResponse: errorResponse)
        }
        
        do {
            return try JSONDecoder().decode(UploadResponse.self, from: data)
        } catch {
            throw APIError.decodingFailed(underlying: error)
        }
    }
    
    private func uploadToGCS(
        data: Data,
        uploadURL: String,
        contentType: String
    ) async throws {
        guard let url = URL(string: uploadURL) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknownError
        }
        
        // GCS returns 200 for successful uploads
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.gcsUploadFailed(statusCode: httpResponse.statusCode)
        }
    }
}
