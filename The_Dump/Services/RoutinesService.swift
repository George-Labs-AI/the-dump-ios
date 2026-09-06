import Foundation

// Client for the Routines JSON API on the Flask frontend
// (The_Dump_Front_End/routes/routines_routes.py). Mirrors the request /
// error-handling pattern in NotesService. Read paths only fetch metadata
// until a single document is opened — GET /documents (all bodies) is
// deliberately not used because one index document is ~217K chars.

/// Thrown by answerAsk when the server refuses the answer with a 409 and
/// hands back the current row (revision mismatch, or already answered).
struct RoutineAnswerConflict: LocalizedError {
    let reason: String
    let currentAsk: RoutineAsk

    var errorDescription: String? {
        if reason == "stale" {
            return "This ask changed on another device. It has been refreshed."
        }
        return "This ask was already answered. It has been refreshed."
    }
}

class RoutinesService {
    static let shared = RoutinesService()

    private let baseURL = "https://thedump.ai"

    private init() {}

#if DEBUG
    private func debugLogRequest(_ request: URLRequest, label: String) {
        let method = request.httpMethod ?? "(nil)"
        let urlString = request.url?.absoluteString ?? "(nil url)"
        let hasAuthHeader = request.value(forHTTPHeaderField: "Authorization") != nil
        print("[RoutinesService][\(label)] Request: \(method) \(urlString) hasAuthorization=\(hasAuthHeader)")
    }

    private func debugLogResponse(data: Data, response: URLResponse, label: String) {
        guard let http = response as? HTTPURLResponse else {
            print("[RoutinesService][\(label)] Response: (non-HTTP)")
            return
        }
        print("[RoutinesService][\(label)] Response: HTTP \(http.statusCode) (\(data.count) bytes)")
        guard !(200...299).contains(http.statusCode) else { return }
        let bodyString = String(data: data, encoding: .utf8) ?? "(non-utf8 body)"
        print("[RoutinesService][\(label)] Error body: \(bodyString.prefix(2000))")
    }
#endif

    // Helper to create an authorized request with the Firebase ID Token
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

    private func pathEncode(_ segment: String) -> String {
        segment.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? segment
    }

    /// Shared send + decode for the plain GET endpoints.
    private func fetch<T: Decodable>(_ type: T.Type, endpoint: String, label: String) async throws -> T {
        let request = try await createRequest(endpoint: endpoint)

        do {
#if DEBUG
            debugLogRequest(request, label: label)
#endif
            let (data, response) = try await URLSession.shared.data(for: request)
#if DEBUG
            debugLogResponse(data: data, response: response, label: label)
#endif

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(underlying: URLError(.badServerResponse))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
                throw APIError.from(statusCode: httpResponse.statusCode, errorResponse: errorResponse)
            }

            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingFailed(underlying: error)
        } catch {
            throw APIError.networkError(underlying: error)
        }
    }

    // MARK: - Routines

    /// GET /api/routines — the user's enabled routines with doc / open-ask counts.
    func fetchRoutines() async throws -> [RoutineSummary] {
        let response = try await fetch(RoutinesListResponse.self, endpoint: "/api/routines", label: "routines")
        return response.routines
    }

    /// GET /api/routines/<slug> — one routine plus document metadata (no bodies).
    func fetchRoutine(slug: String) async throws -> RoutineDetailResponse {
        try await fetch(
            RoutineDetailResponse.self,
            endpoint: "/api/routines/\(pathEncode(slug))",
            label: "routine_detail"
        )
    }

    // MARK: - Documents

    /// GET /api/routines/<slug>/documents/<doc_slug> — one document with its
    /// full body and revision history metadata. Bodies can be very large
    /// (hundreds of KB); callers render them progressively.
    func fetchDocument(routineSlug: String, documentSlug: String) async throws -> RoutineDocument {
        try await fetch(
            RoutineDocument.self,
            endpoint: "/api/routines/\(pathEncode(routineSlug))/documents/\(pathEncode(documentSlug))",
            label: "routine_document"
        )
    }

    // MARK: - Asks

    /// GET /api/routines/<slug>/asks?status=... — status is open|answered|applied|withdrawn|all.
    func fetchAsks(routineSlug: String, status: String = "all") async throws -> [RoutineAsk] {
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "status", value: status)]
        let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""
        let response = try await fetch(
            RoutineAsksResponse.self,
            endpoint: "/api/routines/\(pathEncode(routineSlug))/asks\(query)",
            label: "routine_asks"
        )
        return response.asks
    }

    /// POST /api/routines/<slug>/asks/<ask_id>/answer
    ///
    /// `revision` is the optimistic-concurrency token from the ask as it was
    /// rendered. A 409 (stale revision, or already answered) carries the
    /// current row and is surfaced as RoutineAnswerConflict so the caller
    /// can refresh the card instead of silently overwriting an answer.
    func answerAsk(
        routineSlug: String,
        askID: String,
        choice: RoutineAnswerChoice,
        text: String?,
        revision: Int
    ) async throws -> RoutineAsk {
        let trimmedText = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let payloadText = (trimmedText?.isEmpty ?? true) ? nil : trimmedText

        if choice == .edit && payloadText == nil {
            throw APIError.badRequest(message: "Replacement text is required for an edit")
        }

        var request = try await createRequest(
            endpoint: "/api/routines/\(pathEncode(routineSlug))/asks/\(pathEncode(askID))/answer",
            method: "POST"
        )
        let body = RoutineAnswerRequest(choice: choice.rawValue, text: payloadText, revision: revision)

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw APIError.encodingFailed
        }

        do {
#if DEBUG
            debugLogRequest(request, label: "answer_ask")
#endif
            let (data, response) = try await URLSession.shared.data(for: request)
#if DEBUG
            debugLogResponse(data: data, response: response, label: "answer_ask")
#endif

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(underlying: URLError(.badServerResponse))
            }

            if httpResponse.statusCode == 409,
               let conflict = try? JSONDecoder().decode(RoutineAnswerResponse.self, from: data) {
                throw RoutineAnswerConflict(reason: conflict.error ?? "conflict", currentAsk: conflict.ask)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
                throw APIError.from(statusCode: httpResponse.statusCode, errorResponse: errorResponse)
            }

            return try JSONDecoder().decode(RoutineAnswerResponse.self, from: data).ask
        } catch let error as RoutineAnswerConflict {
            throw error
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingFailed(underlying: error)
        } catch {
            throw APIError.networkError(underlying: error)
        }
    }
}
