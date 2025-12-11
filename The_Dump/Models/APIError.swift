import Foundation
import Combine

enum APIError: LocalizedError {
    case invalidURL
    case encodingFailed
    case networkError(underlying: Error)
    case httpError(statusCode: Int, message: String)
    case decodingFailed(underlying: Error)
    case unauthorized(message: String)
    case badRequest(message: String)
    case serverError(message: String)
    case gcsUploadFailed(statusCode: Int)
    case noAuthToken
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .encodingFailed:
            return "Failed to encode request"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .httpError(let code, let message):
            return "HTTP \(code): \(message)"
        case .decodingFailed:
            return "Failed to decode response"
        case .unauthorized(let message):
            return "Unauthorized: \(message)"
        case .badRequest(let message):
            return "Bad request: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .gcsUploadFailed(let code):
            return "Upload failed (HTTP \(code))"
        case .noAuthToken:
            return "Not authenticated"
        case .unknownError:
            return "Unknown error occurred"
        }
    }
    
    static func from(statusCode: Int, errorResponse: APIErrorResponse?) -> APIError {
        let message = errorResponse?.error ?? "Unknown error"
        switch statusCode {
        case 400:
            return .badRequest(message: message)
        case 401:
            return .unauthorized(message: message)
        case 500...599:
            return .serverError(message: message)
        default:
            return .httpError(statusCode: statusCode, message: message)
        }
    }
}
