import Foundation

// Stacks and bulk actions on several notes at once. These routes live on the
// web server next to the ones in NotesService.swift and accept the same
// Firebase sign-in.
extension NotesService {
    /// A stack's details and every note in it.
    func fetchStack(stackId: String) async throws -> StackResponse {
        guard let id = NotesActionRequest.validStackId(stackId) else {
            throw APIError.badRequest(message: "Invalid stack")
        }
        return try await sendNotesAction(path: "/api/stack/\(id)", method: "GET", body: nil)
    }

    /// Bundle notes (at least 2) into a new stack. Notes already in another
    /// stack move into the new one.
    func stackNotes(noteIds: [String]) async throws -> StackNotesResponse {
        let body = try NotesActionRequest.body(StackNotesRequest(noteIds: noteIds))
        return try await sendNotesAction(path: "/stack_notes", method: "POST", body: body)
    }

    /// Dissolve a stack; its notes become ordinary notes again.
    func unstackNotes(stackId: String) async throws {
        guard let id = NotesActionRequest.validStackId(stackId) else {
            throw APIError.badRequest(message: "Invalid stack")
        }
        let body = try NotesActionRequest.body(UnstackNotesRequest(stackId: id))
        let _: NotesActionErrorResponse = try await sendNotesAction(path: "/unstack_notes", method: "POST", body: body)
    }

    func bulkDeleteNotes(noteIds: [String]) async throws -> BulkDeleteNotesResponse {
        let body = try NotesActionRequest.body(BulkDeleteNotesRequest(noteIds: noteIds))
        return try await sendNotesAction(path: "/bulk_delete_notes", method: "POST", body: body)
    }

    func bulkUpdateNotes(_ update: BulkUpdateNotesRequest) async throws -> BulkUpdateNotesResponse {
        let body = try NotesActionRequest.body(update)
        return try await sendNotesAction(path: "/bulk_update_notes", method: "POST", body: body)
    }

    private func sendNotesAction<Response: Decodable>(path: String, method: String, body: Data?) async throws -> Response {
        let token = try await AuthService.shared.getIDToken()
        guard let request = NotesActionRequest.make(
            baseURL: SharedConstants.baseURL,
            path: path,
            method: method,
            token: token,
            body: body
        ) else {
            throw APIError.invalidURL
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
#if DEBUG
            if let http = response as? HTTPURLResponse {
                print("[NotesService][\(path)] Response: HTTP \(http.statusCode)")
            }
#endif

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(underlying: URLError(.badServerResponse))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw NotesActionRequest.error(statusCode: httpResponse.statusCode, data: data)
            }

            return try JSONDecoder().decode(Response.self, from: data)
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
#if DEBUG
            print("[NotesService][\(path)] Decode failed: \(error)")
#endif
            throw APIError.decodingFailed(underlying: error)
        } catch {
            throw APIError.networkError(underlying: error)
        }
    }
}

/// Request building for the stack and bulk routes, kept free of networking so
/// tests can check exactly what is sent.
enum NotesActionRequest {
    static func make(baseURL: String, path: String, method: String, token: String, body: Data?) -> URLRequest? {
        guard let url = URL(string: "\(baseURL)\(path)") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        return request
    }

    static func body<Body: Encodable>(_ value: Body) throws -> Data {
        do {
            // The default encoder leaves nil optionals out, which the bulk
            // update route reads as "leave this field unchanged".
            return try JSONEncoder().encode(value)
        } catch {
            throw APIError.encodingFailed
        }
    }

    /// Stack ids are UUIDs; anything else is refused before it reaches a URL.
    static func validStackId(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard UUID(uuidString: trimmed) != nil else { return nil }
        return trimmed.lowercased()
    }

    static func error(statusCode: Int, data: Data) -> APIError {
        let decoded = try? JSONDecoder().decode(NotesActionErrorResponse.self, from: data)
        let message = decoded?.message ?? decoded?.error
        return APIError.from(statusCode: statusCode, errorResponse: message.map { APIErrorResponse(error: $0) })
    }
}
