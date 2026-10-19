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

/// Web addresses for a routine's pages, used to send the owner to a computer.
enum RoutineLinks {
    static func connectPath(slug: String) -> String {
        let encoded = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        return "/routines/\(encoded)/connect"
    }

    /// The web's "Connect your runner" page, for finishing on a computer.
    static func connectPageURL(slug: String, baseURL: String = SharedConstants.baseURL) -> URL? {
        URL(string: baseURL + connectPath(slug: slug))
    }
}

/// The words to show for a failed create, preview or pause request. The
/// server's own messages are already written for people ("Select at least
/// one category or subcategory."), so they are shown as they are, without
/// the "Bad request:" prefix the shared error text adds.
enum RoutineErrorText {
    static func message(for error: Error) -> String {
        guard let apiError = error as? APIError else { return error.localizedDescription }
        switch apiError {
        case .unauthorized:
            return "Please sign in again, then try again."
        case .httpError(statusCode: 429, _):
            return "Too many requests. Wait a minute and try again."
        case .badRequest(let message), .conflict(let message), .notFound(let message),
             .serverError(let message), .upstreamFailed(let message):
            return serverMessage(message)
        case .httpError(_, let message):
            return serverMessage(message)
        default:
            return apiError.localizedDescription
        }
    }

    // APIError.from fills in "Unknown error" when the reply had no message.
    private static func serverMessage(_ message: String) -> String {
        message == "Unknown error" || message.isEmpty ? "Request failed. Please try again." : message
    }
}

class RoutinesService {
    static let shared = RoutinesService()

    private let baseURL = SharedConstants.baseURL

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
        return try await send(request, decoding: T.self, label: label)
    }

    /// `fetch` with a JSON body, for the create / preview / pause endpoints.
    /// The bearer token is what lets these skip the web form's security
    /// check, which only applies to signed-in browser sessions.
    private func send<Body: Encodable, T: Decodable>(
        _ body: Body,
        to endpoint: String,
        method: String,
        decoding type: T.Type,
        label: String
    ) async throws -> T {
        var request = try await createRequest(endpoint: endpoint, method: method)
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw APIError.encodingFailed
        }
        return try await send(request, decoding: T.self, label: label)
    }

    private func send<T: Decodable>(_ request: URLRequest, decoding type: T.Type, label: String) async throws -> T {
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

    // MARK: - Creating and pausing

    /// GET /api/routines/scope-options — the categories and sub-categories a
    /// new routine can read from.
    func fetchScopeOptions() async throws -> RoutineScopeOptionsResponse {
        try await fetch(RoutineScopeOptionsResponse.self, endpoint: "/api/routines/scope-options", label: "scope_options")
    }

    /// POST /api/routines/preview — how many notes `scope` matches today.
    /// Reads only; nothing is saved.
    func previewScope(_ scope: RoutineScope) async throws -> RoutinePreviewResponse {
        try await send(
            RoutinePreviewRequest(scope: scope),
            to: "/api/routines/preview",
            method: "POST",
            decoding: RoutinePreviewResponse.self,
            label: "routine_preview"
        )
    }

    /// POST /api/routines — registers the routine. Sending the same body
    /// with the same request ID again returns the routine already saved.
    func createRoutine(_ body: RoutineCreateRequest) async throws -> RoutineCreateResponse {
        try await send(body, to: "/api/routines", method: "POST", decoding: RoutineCreateResponse.self, label: "routine_create")
    }

    /// PATCH /api/routines/<slug> with {paused}. The reply is the routine
    /// with its status worked out again but without its document list, so
    /// it decodes as a summary rather than a detail response.
    func setPaused(_ paused: Bool, routineSlug: String) async throws -> RoutineSummary {
        try await send(
            RoutinePauseRequest(paused: paused),
            to: "/api/routines/\(pathEncode(routineSlug))",
            method: "PATCH",
            decoding: RoutineSummary.self,
            label: "routine_pause"
        )
    }

    /// The runner instructions for one routine, read out of the web's
    /// "Connect your runner" page (see `RunnerInstructionsPage`).
    func fetchRunnerInstructions(routineSlug: String) async throws -> String {
        var request = try await createRequest(endpoint: RoutineLinks.connectPath(slug: routineSlug))
        request.setValue("text/html", forHTTPHeaderField: "Accept")

        do {
#if DEBUG
            debugLogRequest(request, label: "runner_instructions")
#endif
            let (data, response) = try await URLSession.shared.data(for: request)
#if DEBUG
            debugLogResponse(data: data, response: response, label: "runner_instructions")
#endif

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(underlying: URLError(.badServerResponse))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
                throw APIError.from(statusCode: httpResponse.statusCode, errorResponse: errorResponse)
            }

            guard let html = String(data: data, encoding: .utf8),
                  let instructions = RunnerInstructionsPage.instructions(fromHTML: html) else {
                throw APIError.upstreamFailed(message: "The runner instructions could not be read.")
            }
            return instructions
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(underlying: error)
        }
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
