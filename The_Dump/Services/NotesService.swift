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

    // Edit an existing note (partial updates allowed)
    func editNote(
        noteId: String,
        entries: String? = nil,
        title: String? = nil,
        category: String? = nil,
        subCategories: [String]? = nil,
        type: String? = nil,
        tags: [String]? = nil
    ) async throws -> EditNoteResponseNote {
        let cleanedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedCategory = category?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedType = type?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedSubCategories = subCategories?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let cleanedTags = tags?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let entries, entries.utf8.count > 500 * 1024 {
            throw APIError.badRequest(message: "Content too large (max 500KB)")
        }

        let hasUpdate =
            entries != nil ||
            cleanedTitle != nil ||
            cleanedCategory != nil ||
            cleanedSubCategories != nil ||
            cleanedType != nil ||
            cleanedTags != nil

        guard hasUpdate else {
            throw APIError.badRequest(message: "At least one field must be provided for update")
        }

        if let cleanedSubCategories, cleanedSubCategories.count > 3 {
            throw APIError.badRequest(message: "Maximum of 3 sub-categories allowed")
        }

        var request = try await createRequest(endpoint: "/api/edit_note", method: "POST")
        var body = EditNoteRequest(noteId: noteId)
        body.entries = entries
        body.title = cleanedTitle
        body.category = cleanedCategory
        body.subCategories = cleanedSubCategories
        body.type = cleanedType
        body.tags = cleanedTags

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw APIError.encodingFailed
        }

        do {
#if DEBUG
            debugLogRequest(request, label: "edit_note")
#endif
            let (data, response) = try await URLSession.shared.data(for: request)
#if DEBUG
            debugLogResponse(data: data, response: response, label: "edit_note")
#endif

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(underlying: URLError(.badServerResponse))
            }

            let decoded = try JSONDecoder().decode(EditNoteResponse.self, from: data)

            guard (200...299).contains(httpResponse.statusCode), let note = decoded.note else {
                let message = decoded.error ?? "Failed to update note"
                let errorResponse = APIErrorResponse(error: message)
                throw APIError.from(statusCode: httpResponse.statusCode, errorResponse: errorResponse)
            }

            return note
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingFailed(underlying: error)
        } catch {
            throw APIError.networkError(underlying: error)
        }
    }

    // Update user categories
    func updateCategories(_ categories: [Category]) async throws -> UpdateCategoriesResponse {
        guard !categories.isEmpty else {
            throw APIError.badRequest(message: "At least one category is required")
        }

        // Validate all categories have non-empty names
        for category in categories {
            let trimmedName = category.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedName.isEmpty {
                throw APIError.badRequest(message: "Category name cannot be empty")
            }
        }

        var request = try await createRequest(endpoint: "/api/categories/update", method: "POST")
        let body = UpdateCategoriesRequest(categories: categories)

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw APIError.encodingFailed
        }

        do {
#if DEBUG
            debugLogRequest(request, label: "categories_update")
            if let bodyData = request.httpBody,
               let bodyString = String(data: bodyData, encoding: .utf8) {
                print("[NotesService][categories_update] Request body: \(bodyString)")
            }
#endif
            let (data, response) = try await URLSession.shared.data(for: request)
#if DEBUG
            debugLogResponse(data: data, response: response, label: "categories_update")
            // Log the full response body for debugging
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode),
               let bodyString = String(data: data, encoding: .utf8) {
                print("[NotesService][categories_update] Success body: \(bodyString)")
            }
#endif

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(underlying: URLError(.badServerResponse))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
                throw APIError.from(statusCode: httpResponse.statusCode, errorResponse: errorResponse)
            }

            let decoded = try JSONDecoder().decode(UpdateCategoriesResponse.self, from: data)
#if DEBUG
            print("[NotesService][categories_update] Decoded: status=\(decoded.status) count=\(decoded.updatedCount) categories=\(decoded.categories.count)")
            for cat in decoded.categories {
                print("[NotesService][categories_update]   - \(cat.name) (id=\(cat.categoryId), added=\(cat.dateAdded))")
            }
#endif
            return decoded
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
#if DEBUG
            print("[NotesService][categories_update] Decoding error: \(error)")
#endif
            throw APIError.decodingFailed(underlying: error)
        } catch {
            throw APIError.networkError(underlying: error)
        }
    }

    // Create a new sub-category
    func createSubCategory(
        categoryName: String,
        subCatName: String,
        subCatDescription: String? = nil,
        subCatKeywords: String? = nil
    ) async throws {
        let trimmedCategory = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSubCat = subCatName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedCategory.isEmpty else {
            throw APIError.badRequest(message: "Category name is required")
        }

        guard !trimmedSubCat.isEmpty else {
            throw APIError.badRequest(message: "Sub-category name is required")
        }

        var request = try await createRequest(endpoint: "/api/subcategories", method: "POST")
        let body = CreateSubCategoryRequest(
            categoryName: trimmedCategory,
            subCatName: trimmedSubCat,
            subCatDescription: subCatDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
            subCatKeywords: subCatKeywords
        )

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw APIError.encodingFailed
        }

        do {
#if DEBUG
            debugLogRequest(request, label: "create_subcategory")
            if let bodyData = request.httpBody,
               let bodyString = String(data: bodyData, encoding: .utf8) {
                print("[NotesService][create_subcategory] Request body: \(bodyString)")
            }
#endif
            let (data, response) = try await URLSession.shared.data(for: request)
#if DEBUG
            debugLogResponse(data: data, response: response, label: "create_subcategory")
#endif

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(underlying: URLError(.badServerResponse))
            }

            if !(200...299).contains(httpResponse.statusCode) {
                let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
                throw APIError.from(statusCode: httpResponse.statusCode, errorResponse: errorResponse)
            }
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingFailed(underlying: error)
        } catch {
            throw APIError.networkError(underlying: error)
        }
    }
}
