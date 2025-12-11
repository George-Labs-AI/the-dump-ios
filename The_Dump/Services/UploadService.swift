import Foundation
import UIKit
import Combine

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
        // Convert to JPEG
        guard let jpegData = image.jpegData(compressionQuality: 0.85) else {
            throw APIError.encodingFailed
        }
        
        // Generate filename
        let filename = generateFilename(kind: "photo", extension: "jpg")
        
        // Get signed URL
        let response = try await requestSignedURL(
            filename: filename,
            contentType: "image/jpeg",
            idToken: idToken
        )
        
        // Upload to GCS
        try await uploadToGCS(
            data: jpegData,
            uploadURL: response.uploadUrl,
            contentType: "image/jpeg"
        )
        
        return response
    }
    
    // MARK: - Audio Upload
    
    func uploadAudio(
        fileURL: URL,
        userEmail: String,
        idToken: String
    ) async throws -> UploadResponse {
        // Read audio data
        let audioData = try Data(contentsOf: fileURL)
        
        // Check size (100MB limit)
        let maxSize = 100 * 1024 * 1024
        guard audioData.count <= maxSize else {
            throw APIError.badRequest(message: "File exceeds 100MB limit")
        }
        
        // Generate filename
        let filename = generateFilename(kind: "voice", extension: "m4a")
        
        // Get signed URL
        let response = try await requestSignedURL(
            filename: filename,
            contentType: "audio/m4a",
            idToken: idToken
        )
        
        // Upload to GCS
        try await uploadToGCS(
            data: audioData,
            uploadURL: response.uploadUrl,
            contentType: "audio/m4a"
        )
        
        return response
    }
    
    // MARK: - Private Methods
    
    private func generateFilename(kind: String, extension ext: String) -> String {
        let uuid = UUID().uuidString.lowercased()
        return "\(kind)_\(uuid).\(ext)"
    }
    
    private func requestSignedURL(
        filename: String,
        contentType: String,
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
            "isQuickNote": false
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
