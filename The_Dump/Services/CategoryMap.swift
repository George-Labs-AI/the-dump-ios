import Foundation

/// GET /api/category_map: the user's active categories and, for each one, its
/// active sub-categories. The server sends every name lower-cased and trimmed,
/// and keys `subcategoriesByCategory` by the category name in that same form,
/// so look categories up with `subCategories(forCategory:)` rather than by the
/// display name.
struct CategoryMapResponse: Decodable, Equatable {
    let categories: [String]
    let subcategoriesByCategory: [String: [String]]

    enum CodingKeys: String, CodingKey {
        case categories
        case subcategoriesByCategory = "subcategories_by_category"
    }

    init(categories: [String], subcategoriesByCategory: [String: [String]]) {
        self.categories = categories
        self.subcategoriesByCategory = subcategoriesByCategory
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        categories = try c.decodeIfPresent([String].self, forKey: .categories) ?? []
        subcategoriesByCategory = try c.decodeIfPresent([String: [String]].self, forKey: .subcategoriesByCategory) ?? [:]
    }

    /// The active sub-categories of `categoryName`, matched ignoring case and
    /// surrounding spaces. Empty for an unknown or archived category.
    func subCategories(forCategory categoryName: String) -> [String] {
        subcategoriesByCategory[Self.key(categoryName)] ?? []
    }

    /// A name in the form the server uses for keys.
    static func key(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

extension NotesService {
    func fetchCategoryMap() async throws -> CategoryMapResponse {
        guard let url = URL(string: "\(SharedConstants.baseURL)/api/category_map") else {
            throw APIError.invalidURL
        }

        let token = try await AuthService.shared.getIDToken()

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(underlying: URLError(.badServerResponse))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
                throw APIError.from(statusCode: httpResponse.statusCode, errorResponse: errorResponse)
            }

            return try JSONDecoder().decode(CategoryMapResponse.self, from: data)
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingFailed(underlying: error)
        } catch {
            throw APIError.networkError(underlying: error)
        }
    }
}
