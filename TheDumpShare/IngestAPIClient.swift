import Foundation

// MARK: - Response Model

struct IngestResponse: Codable {
    let message: String
    let uuid: String
    let gcsPath: String
    let source: String
    let command: String

    enum CodingKeys: String, CodingKey {
        case message, uuid, source, command
        case gcsPath = "gcs_path"
    }
}

// MARK: - Error Types

enum ShareExtensionError: LocalizedError, Equatable {
    case notAuthenticated
    case badRequest(String)
    case unauthorized
    case noAccount
    case rateLimited
    case serverError(String)
    case networkError(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please open The Dump app and sign in."
        case .badRequest(let message):
            return "Invalid request: \(message)"
        case .unauthorized:
            return "Session expired. Please open The Dump app to refresh."
        case .noAccount:
            return "No account found. Please sign up in The Dump app."
        case .rateLimited:
            return "Monthly usage limit reached."
        case .serverError(let message):
            return "Server error: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Unexpected server response."
        }
    }
}

// MARK: - Error Response

private struct ErrorResponse: Codable {
    let error: String
}

// MARK: - API Client

struct IngestAPIClient {
    private let tokenManager: TokenManager
    private let urlSession: URLSession

    init(tokenManager: TokenManager = TokenManager(), urlSession: URLSession = .shared) {
        self.tokenManager = tokenManager
        self.urlSession = urlSession
    }

    /// Sends content to the ingest endpoint.
    func ingest(
        content: SharedContent,
        source: String,
        command: String,
        title: String?
    ) async throws -> IngestResponse {
        // 1. Get token
        guard let token = tokenManager.getToken() else {
            throw ShareExtensionError.notAuthenticated
        }

        // 2. Build URL
        guard let url = URL(string: "\(SharedConstants.baseURL)\(SharedConstants.ingestEndpoint)") else {
            throw ShareExtensionError.invalidResponse
        }

        // 3. Build request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 4. Build JSON body
        var body: [String: Any] = [
            "source": source,
            "command": command,
        ]

        if let title {
            body["title"] = title
        }

        switch content {
        case .text(let text):
            body["messages"] = [
                ["role": "user", "content": text]
            ]
        case .url(let url):
            body["url"] = url.absoluteString
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // 5. Execute request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw ShareExtensionError.networkError(error.localizedDescription)
        }

        // 6. Handle response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ShareExtensionError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            let message = errorResponse?.error ?? "Unknown error"

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
            return try JSONDecoder().decode(IngestResponse.self, from: data)
        } catch {
            throw ShareExtensionError.invalidResponse
        }
    }
}
