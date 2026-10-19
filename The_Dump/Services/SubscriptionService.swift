import Foundation
#if DEBUG
import os.log
#endif

class SubscriptionService {
    static let shared = SubscriptionService()

    private let baseURL = SharedConstants.baseURL

    private init() {}

#if DEBUG
    private func debugLogRequest(_ request: URLRequest, label: String) {
        let method = request.httpMethod ?? "(nil)"
        let urlString = request.url?.absoluteString ?? "(nil url)"
        print("[SubscriptionService][\(label)] Request: \(method) \(urlString)")
    }

    private func debugLogResponse(data: Data, response: URLResponse, label: String) {
        guard let http = response as? HTTPURLResponse else { return }
        print("[SubscriptionService][\(label)] Response: HTTP \(http.statusCode)")
        guard !(200...299).contains(http.statusCode) else { return }
        let bodyString = String(data: data, encoding: .utf8) ?? "(non-utf8 body)"
        print("[SubscriptionService][\(label)] Error body: \(bodyString.prefix(2000))")
    }
#endif

    private func createRequest(endpoint: String, method: String = "GET") async throws -> URLRequest {
        let token = try await AuthService.shared.getIDToken()

        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    func fetchUsageStatus() async throws -> UsageStatusResponse {
        let request = try await createRequest(endpoint: "/api/usage-status")

        do {
#if DEBUG
            debugLogRequest(request, label: "usage-status")
#endif
            let (data, response) = try await URLSession.shared.data(for: request)
#if DEBUG
            debugLogResponse(data: data, response: response, label: "usage-status")
#endif

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(underlying: URLError(.badServerResponse))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
                throw APIError.from(statusCode: httpResponse.statusCode, errorResponse: errorResponse)
            }

            return try JSONDecoder().decode(UsageStatusResponse.self, from: data)
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingFailed(underlying: error)
        } catch {
            throw APIError.networkError(underlying: error)
        }
    }

    func verifyPurchase(signedTransaction: String) async throws -> VerifyPurchaseResponse {
        var request = try await createRequest(endpoint: "/api/verify-ios-purchase", method: "POST")

        let body = ["signed_transaction": signedTransaction]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
#if DEBUG
            debugLogRequest(request, label: "verify-purchase")
#endif
            let (data, response) = try await URLSession.shared.data(for: request)
#if DEBUG
            debugLogResponse(data: data, response: response, label: "verify-purchase")
#endif

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(underlying: URLError(.badServerResponse))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
                throw APIError.from(statusCode: httpResponse.statusCode, errorResponse: errorResponse)
            }

            return try JSONDecoder().decode(VerifyPurchaseResponse.self, from: data)
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingFailed(underlying: error)
        } catch {
            throw APIError.networkError(underlying: error)
        }
    }
}
