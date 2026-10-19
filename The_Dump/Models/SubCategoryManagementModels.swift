import Foundation

// Managing a category's sub-categories from Settings: list, edit, delete
// (which archives) and restore. The routes live on the web server next to
// the category ones and accept the same Firebase sign-in.

// MARK: - Sub-category object

/// A routine that reads a sub-category, named on the delete warning.
struct SubCategoryRoutine: Decodable, Equatable, Hashable {
    let slug: String
    let name: String

    init(slug: String, name: String) {
        self.slug = slug
        self.name = name
    }

    enum CodingKeys: String, CodingKey {
        case slug
        case name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let slug = try container.decodeIfPresent(String.self, forKey: .slug) ?? ""
        let name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.slug = slug
        // A routine with no name is still named by something on the warning.
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? slug : name
    }
}

/// One sub-category as every sub-category route returns it. Only the id and
/// the name are required; anything else missing takes a harmless default,
/// and keys this app doesn't know are ignored.
struct SubCategoryItem: Decodable, Identifiable, Equatable, Hashable {
    let subCatId: Int
    let categoryId: Int?
    /// Stored lower-case by the server.
    let name: String
    let description: String?
    let keywords: [String]
    /// Notes that carry this sub-category now, counted by the server.
    let noteCount: Int
    let archived: Bool
    let archivedAt: String?
    /// Routines whose notes include this sub-category.
    let routines: [SubCategoryRoutine]

    var id: Int { subCatId }

    init(
        subCatId: Int,
        categoryId: Int? = nil,
        name: String,
        description: String? = nil,
        keywords: [String] = [],
        noteCount: Int = 0,
        archived: Bool = false,
        archivedAt: String? = nil,
        routines: [SubCategoryRoutine] = []
    ) {
        self.subCatId = subCatId
        self.categoryId = categoryId
        self.name = name
        self.description = description
        self.keywords = keywords
        self.noteCount = noteCount
        self.archived = archived
        self.archivedAt = archivedAt
        self.routines = routines
    }

    enum CodingKeys: String, CodingKey {
        case subCatId = "sub_cat_id"
        case categoryId = "category_id"
        case name
        case description
        case keywords
        case noteCount = "note_count"
        case archived
        case archivedAt = "archived_at"
        case routines
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subCatId = try container.decodeFlexibleInt(forKey: .subCatId)
        categoryId = try? container.decodeFlexibleInt(forKey: .categoryId)
        name = try container.decode(String.self, forKey: .name)
        description = try? container.decodeIfPresent(String.self, forKey: .description)
        keywords = container.decodeKeywords(forKey: .keywords)
        noteCount = max(0, (try? container.decodeFlexibleInt(forKey: .noteCount)) ?? 0)
        archivedAt = try? container.decodeIfPresent(String.self, forKey: .archivedAt)
        let archivedFlag = try? container.decodeIfPresent(Bool.self, forKey: .archived)
        archived = archivedFlag ?? (archivedAt != nil)
        routines = (try? container.decodeIfPresent([LossyDecodable<SubCategoryRoutine>].self, forKey: .routines))?
            .compactMap(\.value) ?? []
    }
}

// MARK: - Responses

/// GET /api/categories/<id>/subcategories
struct SubCategoryListResponse: Decodable {
    let subcategories: [SubCategoryItem]

    enum CodingKeys: String, CodingKey {
        case subcategories
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // One unreadable entry shouldn't hide the others.
        subcategories = (try container.decodeIfPresent([LossyDecodable<SubCategoryItem>].self, forKey: .subcategories))?
            .compactMap(\.value) ?? []
    }
}

/// PATCH /api/subcategories/<id>
struct UpdateSubCategoryResponse: Decodable {
    let subcategory: SubCategoryItem?
    /// Notes whose stored name was changed by a rename.
    let notesRenamed: Int

    enum CodingKeys: String, CodingKey {
        case subcategory
        case notesRenamed = "notes_renamed"
    }

    init(subcategory: SubCategoryItem?, notesRenamed: Int = 0) {
        self.subcategory = subcategory
        self.notesRenamed = notesRenamed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subcategory = try container.decodeIfPresent(SubCategoryItem.self, forKey: .subcategory)
        notesRenamed = (try? container.decodeFlexibleInt(forKey: .notesRenamed)) ?? 0
    }
}

/// POST /api/subcategories/<id>/archive
struct ArchiveSubCategoryResponse: Decodable, Equatable {
    /// Notes the sub-category was taken off.
    let notesUpdated: Int
    /// Notes left with two sub-categories that the server checks again.
    let notesToRecheck: Int

    enum CodingKeys: String, CodingKey {
        case notesUpdated = "notes_updated"
        case notesToRecheck = "notes_to_recheck"
    }

    init(notesUpdated: Int = 0, notesToRecheck: Int = 0) {
        self.notesUpdated = notesUpdated
        self.notesToRecheck = notesToRecheck
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        notesUpdated = (try? container.decodeFlexibleInt(forKey: .notesUpdated)) ?? 0
        notesToRecheck = (try? container.decodeFlexibleInt(forKey: .notesToRecheck)) ?? 0
    }
}

/// POST /api/subcategories/<id>/restore
struct RestoreSubCategoryResponse: Decodable {
    let subcategory: SubCategoryItem?

    init(subcategory: SubCategoryItem?) {
        self.subcategory = subcategory
    }
}

// MARK: - Requests

/// The PATCH body. Only the fields that changed are set; the default
/// JSONEncoder leaves nil ones out, which the server reads as "unchanged".
/// An empty description clears it; an empty keyword list clears them.
struct SubCategoryUpdateRequest: Encodable, Equatable {
    var name: String?
    var description: String?
    var keywords: [String]?

    var isEmpty: Bool {
        name == nil && description == nil && keywords == nil
    }
}

/// The sub-category routes, kept free of networking so tests can check
/// exactly what is sent.
enum SubCategoryEndpoint: Equatable {
    /// Always asks for archived ones too; the screen splits them.
    case list(categoryId: Int)
    case update(subCatId: Int, SubCategoryUpdateRequest)
    case archive(subCatId: Int)
    case restore(subCatId: Int)

    var path: String {
        switch self {
        case .list(let categoryId):
            return "/api/categories/\(categoryId)/subcategories?include_archived=1"
        case .update(let subCatId, _):
            return "/api/subcategories/\(subCatId)"
        case .archive(let subCatId):
            return "/api/subcategories/\(subCatId)/archive"
        case .restore(let subCatId):
            return "/api/subcategories/\(subCatId)/restore"
        }
    }

    var method: String {
        switch self {
        case .list:
            return "GET"
        case .update:
            return "PATCH"
        case .archive, .restore:
            return "POST"
        }
    }

    /// Archive and restore send an empty JSON object rather than no body, so
    /// a server that reads the body as JSON never sees an empty one.
    func body() throws -> Data? {
        switch self {
        case .list:
            return nil
        case .update(_, let update):
            return try NotesActionRequest.body(update)
        case .archive, .restore:
            return Data("{}".utf8)
        }
    }
}

// MARK: - Editing

/// The edit screen's fields and rules, kept out of the view so they can be
/// unit-tested. Names follow the category rules: trimmed, at most 80
/// characters counted as the server counts them, and unique within the
/// category ignoring case, archived sub-categories included. The server
/// stores names lower-case, so a change of case alone is not a rename.
struct SubCategoryEditDraft: Equatable {
    let original: SubCategoryItem
    var name: String
    var description: String
    var keywordsText: String

    init(_ original: SubCategoryItem) {
        self.original = original
        name = original.name
        description = original.description ?? ""
        keywordsText = original.keywords.joined(separator: ", ")
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedDescription: String {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var keywords: [String] {
        SubCategoryEditDraft.parseKeywords(keywordsText)
    }

    var isNameBlank: Bool {
        trimmedName.isEmpty
    }

    var isRename: Bool {
        !isNameBlank && trimmedName.lowercased() != original.name.lowercased()
    }

    /// The server's message for a name already used in this category, or
    /// nil when the name is free. `siblings` is every sub-category of the
    /// category, active and archived; this one is skipped.
    func nameClash(among siblings: [SubCategoryItem]) -> String? {
        guard isRename else { return nil }
        let wanted = trimmedName.lowercased()
        let clash = siblings.first { sibling in
            sibling.subCatId != original.subCatId
                && sibling.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == wanted
        }
        guard let clash else { return nil }
        return clash.archived
            ? SubCategoryWording.archivedNameTaken(clash.name)
            : SubCategoryWording.nameTaken(clash.name)
    }

    /// Only what changed, so an untouched field is never sent.
    var request: SubCategoryUpdateRequest {
        var update = SubCategoryUpdateRequest()
        if isRename {
            // Lower-case, as the server stores it and the web sends it.
            update.name = trimmedName.lowercased()
        }
        if trimmedDescription != (original.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines) {
            update.description = trimmedDescription
        }
        if keywords != original.keywords {
            update.keywords = keywords
        }
        return update
    }

    func canSave(among siblings: [SubCategoryItem]) -> Bool {
        !isNameBlank && nameClash(among: siblings) == nil && !request.isEmpty
    }

    static func parseKeywords(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Words (the same on the web)

enum SubCategoryWording {
    static let sectionTitle = "Sub-categories"
    static let archivedTitle = "Archived"
    static let editTitle = "Edit sub-category"
    static let deleteButton = "Delete sub-category"
    static let restoreButton = "Restore"
    static let renameHelp = "A new name shows on every note that has this sub-category."
    static let emptyList = "No sub-categories yet."
    static let loadFailed = "Could not load the sub-categories. Try again."
    static let saveFailed = "Could not save the sub-category. Please try again."
    static let deleteFailed = "Could not delete the sub-category. Please try again."

    static func restoreFailed(_ name: String) -> String {
        "Couldn't restore \"\(name)\". Please try again."
    }

    static func nameTooLong(_ limit: Int) -> String {
        "Sub-category names can be at most \(limit) characters."
    }

    static func noteCount(_ count: Int) -> String {
        count == 1 ? "1 note" : "\(count) notes"
    }

    /// "Delete "grocery lists"? 7 notes will lose this sub-category. You can
    /// restore it later."
    static func deleteConfirmation(name: String, noteCount count: Int) -> String {
        "Delete \"\(name)\"? \(noteCount(count)) will lose this sub-category. You can restore it later."
    }

    /// One warning per routine that reads the sub-category, shown before
    /// deleting it. The routines themselves are left as they are.
    static func routineWarnings(_ routines: [SubCategoryRoutine]) -> [String] {
        routines.map { "Routine \($0.name) reads this sub-category. It will stop getting new notes from it." }
    }

    /// The whole message of the delete confirmation: the question, then the
    /// routine warnings, as on the web.
    static func deleteMessage(for item: SubCategoryItem) -> String {
        let confirmation = deleteConfirmation(name: item.name, noteCount: item.noteCount)
        let warnings = routineWarnings(item.routines)
        guard !warnings.isEmpty else { return confirmation }
        return confirmation + "\n\n" + warnings.joined(separator: "\n")
    }

    static func nameTaken(_ name: String) -> String {
        "This category already has a sub-category called \"\(name)\"."
    }

    static func archivedNameTaken(_ name: String) -> String {
        "This category already has an archived sub-category called \"\(name)\". Restore it instead."
    }

    /// The server's own words for a refused request (it sends plain
    /// sentences such as the name-taken ones above), or `fallback` when it
    /// sent none or the request never got an answer.
    static func message(for error: Error, fallback: String) -> String {
        guard let apiError = error as? APIError else { return fallback }
        switch apiError {
        case .badRequest(let message), .conflict(let message), .notFound(let message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty || trimmed == "Unknown error" ? fallback : trimmed
        default:
            return fallback
        }
    }
}

// MARK: - Decoding helpers

/// Decodes a value, or nil if this one entry can't be read.
private struct LossyDecodable<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}

private extension KeyedDecodingContainer {
    /// An integer sent as a number or as a string of digits.
    func decodeFlexibleInt(forKey key: Key) throws -> Int {
        if let number = try? decode(Int.self, forKey: key) {
            return number
        }
        let text = try decode(String.self, forKey: key)
        guard let number = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Not an integer: \(text)")
        }
        return number
    }

    /// Keywords sent as a list, or as one string in the "{a, b}" or "a, b"
    /// form older rows use. Missing or unreadable means none.
    func decodeKeywords(forKey key: Key) -> [String] {
        if let list = try? decodeIfPresent([String].self, forKey: key) {
            return list.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        if let text = try? decodeIfPresent(String.self, forKey: key) {
            let inner = text.trimmingCharacters(in: CharacterSet(charactersIn: "{} \n\t"))
            return SubCategoryEditDraft.parseKeywords(inner)
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
                .filter { !$0.isEmpty }
        }
        return []
    }
}
