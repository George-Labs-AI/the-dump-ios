import Foundation

// Managing a category's sub-categories from Settings. These routes live on
// the web server next to the ones in NotesService.swift and accept the same
// Firebase sign-in.
extension NotesService {
    /// Every sub-category of the category, archived ones included.
    func fetchSubCategories(categoryId: Int) async throws -> [SubCategoryItem] {
        let response: SubCategoryListResponse = try await sendSubCategoryRequest(.list(categoryId: categoryId))
        return response.subcategories
    }

    /// Change the name, description or keywords. A rename also changes the
    /// name stored on every note that has the sub-category.
    func updateSubCategory(id subCatId: Int, update: SubCategoryUpdateRequest) async throws -> UpdateSubCategoryResponse {
        try await sendSubCategoryRequest(.update(subCatId: subCatId, update))
    }

    /// "Delete": archive the sub-category and take it off every note that
    /// has it. Archiving one that is already archived succeeds.
    func archiveSubCategory(id subCatId: Int) async throws -> ArchiveSubCategoryResponse {
        try await sendSubCategoryRequest(.archive(subCatId: subCatId))
    }

    /// Make an archived sub-category active again. Notes don't get it back.
    /// Fails with a conflict when an active one now has its name.
    func restoreSubCategory(id subCatId: Int) async throws -> RestoreSubCategoryResponse {
        try await sendSubCategoryRequest(.restore(subCatId: subCatId))
    }

    private func sendSubCategoryRequest<Response: Decodable>(_ endpoint: SubCategoryEndpoint) async throws -> Response {
        let token = try await AuthService.shared.getIDToken()
        guard let request = NotesActionRequest.make(
            baseURL: SharedConstants.baseURL,
            path: endpoint.path,
            method: endpoint.method,
            token: token,
            body: try endpoint.body()
        ) else {
            throw APIError.invalidURL
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
#if DEBUG
            if let http = response as? HTTPURLResponse {
                print("[NotesService][\(endpoint.method) \(endpoint.path)] Response: HTTP \(http.statusCode)")
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
            print("[NotesService][\(endpoint.path)] Decode failed: \(error)")
#endif
            throw APIError.decodingFailed(underlying: error)
        } catch {
            throw APIError.networkError(underlying: error)
        }
    }
}
