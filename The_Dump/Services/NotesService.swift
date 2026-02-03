import Foundation
#if DEBUG
import os.log
#endif

class NotesService {
    static let shared = NotesService()
    
    // ⚠️ Update this URL to match your deployment or local dev environment
    private let baseURL = "https://thedump.ai" 
    
    private init() {}

#if DEBUG
    private func debugLogRequest(_ request: URLRequest, label: String) {
        let method = request.httpMethod ?? "(nil)"
        let urlString = request.url?.absoluteString ?? "(nil url)"
        let hasAuthHeader = request.value(forHTTPHeaderField: "Authorization") != nil
        let contentType = request.value(forHTTPHeaderField: "Content-Type") ?? "(none)"
        let accept = request.value(forHTTPHeaderField: "Accept") ?? "(none)"
        
        let querySummary: String = {
            guard let url = request.url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                return "(no query)"
            }
            let items = components.queryItems ?? []
            guard !items.isEmpty else { return "(no query)" }
            return items
                .map { "\($0.name)=\($0.value ?? "")" }
                .joined(separator: "&")
        }()
        
        print("[NotesService][\(label)] Request: \(method) \(urlString)")
        print("[NotesService][\(label)] Headers: hasAuthorization=\(hasAuthHeader) contentType=\(contentType) accept=\(accept)")
        print("[NotesService][\(label)] Query: \(querySummary)")
    }
    
    private func debugLogResponse(data: Data, response: URLResponse, label: String) {
        guard let http = response as? HTTPURLResponse else {
            print("[NotesService][\(label)] Response: (non-HTTP)")
            return
        }
        
        print("[NotesService][\(label)] Response: HTTP \(http.statusCode)")
        
        // Only dump body on errors to avoid noisy logs.
        guard !(200...299).contains(http.statusCode) else { return }
        
        let bodyString = String(data: data, encoding: .utf8) ?? "(non-utf8 body, \(data.count) bytes)"
        let truncated: String
        if bodyString.count > 2000 {
            let idx = bodyString.index(bodyString.startIndex, offsetBy: 2000)
            truncated = String(bodyString[..<idx]) + "…(truncated)"
        } else {
            truncated = bodyString
        }
        
        print("[NotesService][\(label)] Error body: \(truncated)")
    }
#endif
    
    // Helper to create an authorized request with the Firebase ID Token
    private func createRequest(endpoint: String, method: String = "GET") async throws -> URLRequest {
        // 1. Get the fresh Firebase token from existing AuthService
        let token = try await AuthService.shared.getIDToken()
        
        // 2. Construct the URL
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        // 3. Build the request
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        return request
    }
    
    // Fetch the sidebar counts
    func fetchCounts() async throws -> NoteCountsResponse {
        let request = try await createRequest(endpoint: "/api/note_counts")
        
        do {
#if DEBUG
            debugLogRequest(request, label: "note_counts")
#endif
            let (data, response) = try await URLSession.shared.data(for: request)
#if DEBUG
            debugLogResponse(data: data, response: response, label: "note_counts")
#endif
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(underlying: URLError(.badServerResponse))
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.httpError(statusCode: httpResponse.statusCode, message: "Failed to fetch counts")
            }
            
            return try JSONDecoder().decode(NoteCountsResponse.self, from: data)
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingFailed(underlying: error)
        } catch {
            throw APIError.networkError(underlying: error)
        }
    }
    
    // Fetch the list of notes (with pagination & filtering)
    func fetchNotes(
        limit: Int = 30,
        cursorTime: String? = nil,
        cursorId: String? = nil,
        categoryName: String? = nil,
        mimeType: String? = nil,
        mimeGroup: String? = nil,
        subCatName: String? = nil,
        startTime: String? = nil,
        endTime: String? = nil,
        tz: String? = nil,
        q: String? = nil,
        noteType: String? = nil
    ) async throws -> NoteListResponse {
        // Build query parameters
        guard var components = URLComponents(string: "\(baseURL)/api/pull_notes") else {
            throw APIError.invalidURL
        }

        var queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]

        func addQueryItem(_ name: String, _ value: String?) {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let trimmed, !trimmed.isEmpty else { return }
            queryItems.append(URLQueryItem(name: name, value: trimmed))
        }

        addQueryItem("cursor_time", cursorTime)
        addQueryItem("cursor_id", cursorId)
        addQueryItem("category_name", categoryName)
        addQueryItem("mime_type", mimeType)
        addQueryItem("mime_group", mimeGroup)
        addQueryItem("sub_cat_name", subCatName)
        addQueryItem("start_time", startTime)
        addQueryItem("end_time", endTime)
        addQueryItem("tz", tz)
        addQueryItem("q", q)
        addQueryItem("note_type", noteType)

        components.queryItems = queryItems
        
        guard let url = components.url else { throw APIError.invalidURL }

        // Create request manually since we used URLComponents
        let token = try await AuthService.shared.getIDToken()

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
#if DEBUG
            debugLogRequest(request, label: "pull_notes")
#endif
            let (data, response) = try await URLSession.shared.data(for: request)
#if DEBUG
            debugLogResponse(data: data, response: response, label: "pull_notes")
#endif
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(underlying: URLError(.badServerResponse))
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
                throw APIError.from(statusCode: httpResponse.statusCode, errorResponse: errorResponse)
            }
            
            return try JSONDecoder().decode(NoteListResponse.self, from: data)
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingFailed(underlying: error)
        } catch {
            throw APIError.networkError(underlying: error)
        }
    }
    
    // Fetch full content for specific notes
    func fetchFullNote(ids: [String]) async throws -> [NoteDetail] {
        var request = try await createRequest(endpoint: "/api/pull_full_notes", method: "POST")
        
        let body = ["note_ids": ids]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
#if DEBUG
            debugLogRequest(request, label: "pull_full_notes")
#endif
            let (data, response) = try await URLSession.shared.data(for: request)
#if DEBUG
            debugLogResponse(data: data, response: response, label: "pull_full_notes")
#endif
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(underlying: URLError(.badServerResponse))
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.httpError(statusCode: httpResponse.statusCode, message: "Failed to fetch note details")
            }
            
            let responseObj = try JSONDecoder().decode(NoteDetailResponse.self, from: data)
            return responseObj.notes
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingFailed(underlying: error)
        } catch {
            throw APIError.networkError(underlying: error)
        }
    }
}
