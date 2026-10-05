import Foundation

// MARK: - Response Model

/// The subset of the signed-upload response the extension needs.
/// (Mirrors `UploadResponse` in the main app, which also decodes metadata.)
struct SignedUploadResponse: Codable {
    let uploadUrl: String
    let storagePath: String
    let uuid: String
}

private struct ErrorResponse: Codable {
    let error: String
}

// MARK: - Client

/// Uploads a photo the same way the main app does: ask the backend for a
/// signed GCS URL, then PUT the bytes to it. Each call gets its own uuid, so
/// each photo becomes its own note.
struct PhotoUploadClient {
    private let tokenManager: TokenManager
    private let urlSession: URLSession

    init(tokenManager: TokenManager = TokenManager(), urlSession: URLSession = .shared) {
        self.tokenManager = tokenManager
        self.urlSession = urlSession
    }

    func upload(jpegData: Data) async throws -> SignedUploadResponse {
        guard let token = tokenManager.getToken() else {
            throw ShareExtensionError.notAuthenticated
        }

        let filename = "photo_\(UUID().uuidString.lowercased()).jpg"
        let signed = try await requestSignedURL(filename: filename, contentType: "image/jpeg", token: token)
        try await put(jpegData, to: signed.uploadUrl, contentType: "image/jpeg")
        return signed
    }

    // MARK: - Private

    private func requestSignedURL(filename: String, contentType: String, token: String) async throws -> SignedUploadResponse {
        guard let url = URL(string: "\(SharedConstants.baseURL)\(SharedConstants.uploadFileEndpoint)") else {
            throw ShareExtensionError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "filename": filename,
            "contentType": contentType,
            "isQuickNote": false
        ] as [String: Any])

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw ShareExtensionError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ShareExtensionError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error ?? "Unknown error"
            switch httpResponse.statusCode {
            case 400:
                throw ShareExtensionError.badRequest(message)
            case 401:
                throw ShareExtensionError.unauthorized
            case 402:
                throw ShareExtensionError.noAccount
            case 429:
                throw ShareExtensionError.rateLimited
            case 500...599:
                throw ShareExtensionError.serverError(message)
            default:
                throw ShareExtensionError.serverError("HTTP \(httpResponse.statusCode): \(message)")
            }
        }

        do {
            return try JSONDecoder().decode(SignedUploadResponse.self, from: data)
        } catch {
            throw ShareExtensionError.invalidResponse
        }
    }

    private func put(_ data: Data, to uploadURL: String, contentType: String) async throws {
        guard let url = URL(string: uploadURL) else {
            throw ShareExtensionError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        // Must match the content type the signed URL was issued for.
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let response: URLResponse
        do {
            response = try await urlSession.data(for: request).1
        } catch {
            throw ShareExtensionError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ShareExtensionError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ShareExtensionError.serverError("Upload failed (HTTP \(httpResponse.statusCode))")
        }
    }
}
