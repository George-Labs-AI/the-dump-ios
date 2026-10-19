import Foundation

/// One entry in the note screen's category picker.
struct NoteCategoryChoice: Equatable {
    /// Nil only for a note's own category when the server gave it no ID.
    let id: Int?
    let name: String
    /// What the picker shows, e.g. "Old projects (archived)".
    let label: String

    /// Unique per entry, for ForEach (`id` alone can be nil).
    var key: String { id.map { "category-\($0)" } ?? "current" }
}

/// One entry in the note screen's type picker.
struct NoteTypeChoice: Equatable {
    /// What is saved; "" for a note that has no type.
    let value: String
    let label: String
}

/// What the edit pickers can offer: the user's active categories and each
/// one's sub-categories.
struct NoteEditOptions: Equatable {
    /// Active categories, in the server's order (by name).
    var categories: [NoteCategoryChoice]
    /// From /api/category_map: lower-case category name -> lower-case
    /// sub-category names.
    var subCategoriesByCategory: [String: [String]]
    /// False until the user's categories have arrived, so a note's category
    /// isn't called archived just because the list hasn't loaded.
    var isLoaded: Bool

    static let empty = NoteEditOptions(categories: [], subCategoriesByCategory: [:], isLoaded: false)

    init(categories: [NoteCategoryChoice], subCategoriesByCategory: [String: [String]], isLoaded: Bool = true) {
        self.categories = categories
        self.subCategoriesByCategory = subCategoriesByCategory
        self.isLoaded = isLoaded
    }

    init(categories: [CategoryResponse], map: CategoryMapResponse?) {
        self.categories = categories
            .filter { $0.archived != true }
            .map { NoteCategoryChoice(id: $0.categoryId, name: $0.name, label: $0.name) }
        self.subCategoriesByCategory = map?.subcategoriesByCategory ?? [:]
        self.isLoaded = true
    }

    func subCategories(forCategoryNamed name: String?) -> [String] {
        subCategoriesByCategory[NoteEditDraft.normalized(name ?? "")] ?? []
    }

    func category(withID id: Int) -> NoteCategoryChoice? {
        categories.first { $0.id == id }
    }
}

/// The note screen's edit mode: what the note had when editing started and
/// what the user has chosen since. Pure value logic, so the rules can be
/// unit-tested:
/// - a note always keeps a category (there is no "none" choice);
/// - changing the category drops sub-categories the new one doesn't have,
///   and going back to the note's own category restores its sub-categories;
/// - at most 3 sub-categories;
/// - only fields the user actually changed are sent. Category, sub-categories
///   and type are sent only when changed, so a note in an archived category,
///   or with a type from before the current list, keeps them on a text edit.
struct NoteEditDraft: Equatable {
    static let maxSubCategories = 3
    static let maxContentBytes = 500 * 1024

    // What the note had when editing started.
    let originalTitle: String
    let originalContent: String
    private(set) var originalCategoryId: Int?
    let originalCategoryName: String?
    let originalSubCategories: [String]
    let originalType: String

    var title: String
    var content: String
    private(set) var categoryId: Int?
    private(set) var categoryName: String?
    private(set) var subCategories: [String]
    /// The chosen type; "" when the note has none and the user picked none.
    var noteType: String

    init(
        title: String = "",
        content: String = "",
        categoryId: Int? = nil,
        categoryName: String? = nil,
        subCategories: [String] = [],
        noteType: String = "",
        noteTypes: [String] = []
    ) {
        let cleanType = noteType.trimmingCharacters(in: .whitespacesAndNewlines)
        // Use the list's spelling when the saved type matches one ignoring case.
        let type = noteTypes.first { Self.normalized($0) == Self.normalized(cleanType) } ?? cleanType

        originalTitle = title
        originalContent = content
        originalCategoryId = categoryId
        originalCategoryName = categoryName
        originalSubCategories = subCategories
        originalType = type

        self.title = title
        self.content = content
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.subCategories = subCategories
        self.noteType = type
    }

    init(note: NoteDetail, noteTypes: [String]) {
        self.init(
            title: note.title ?? "",
            content: note.note_content,
            categoryId: note.category_id,
            categoryName: note.category_name,
            subCategories: note.sub_cat_names ?? [],
            noteType: note.note_type ?? "",
            noteTypes: noteTypes
        )
    }

    nonisolated static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - Category

    /// An older note can carry a category name but no ID. When an active
    /// category has that name, it is the same category: adopt its ID so the
    /// picker shows it selected and saving doesn't count it as a move.
    mutating func adoptCategoryID(from options: NoteEditOptions) {
        guard categoryId == nil, originalCategoryId == nil,
              let name = categoryName, !Self.normalized(name).isEmpty,
              let match = options.categories.first(where: { Self.normalized($0.name) == Self.normalized(name) })
        else { return }
        categoryId = match.id
        originalCategoryId = match.id
    }

    /// The category picker's entries: the active categories, plus the note's
    /// own category when it isn't one of them (archived, or not found), so
    /// the picker never shows a blank.
    func categoryChoices(from options: NoteEditOptions) -> [NoteCategoryChoice] {
        var choices = options.categories
        let isActive = originalCategoryId.map { id in choices.contains { $0.id == id } } ?? false
        if !isActive {
            let name = (originalCategoryName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let label: String
            if name.isEmpty {
                label = "No category"
            } else if originalCategoryId != nil && options.isLoaded {
                // Categories are never deleted outright, so an ID missing
                // from the active list is an archived category.
                label = "\(name) (archived)"
            } else {
                label = name
            }
            choices.insert(NoteCategoryChoice(id: originalCategoryId, name: name, label: label), at: 0)
        }
        return choices
    }

    /// Move the note to another category. Sub-categories the new category
    /// doesn't offer are dropped; going back to the note's own category puts
    /// its sub-categories back.
    mutating func selectCategory(_ choice: NoteCategoryChoice, availableSubCategories: [String]) {
        guard choice.id != categoryId else { return }
        categoryId = choice.id
        categoryName = choice.name
        if choice.id == originalCategoryId {
            subCategories = originalSubCategories
            return
        }
        let available = Set(availableSubCategories.map(Self.normalized))
        subCategories = subCategories.filter { available.contains(Self.normalized($0)) }
    }

    var categoryChanged: Bool {
        categoryId != nil && categoryId != originalCategoryId
    }

    // MARK: - Sub-categories

    /// The sub-categories the user can pick for the chosen category. For the
    /// note's own category this includes the ones it already has, even if
    /// the category or the sub-category has since been archived.
    func subCategoryChoices(from options: NoteEditOptions) -> [String] {
        var choices = options.subCategories(forCategoryNamed: categoryName)
        let extras = categoryId == originalCategoryId ? originalSubCategories + subCategories : subCategories
        for name in extras where !choices.contains(where: { Self.normalized($0) == Self.normalized(name) }) {
            choices.append(name)
        }
        return choices
    }

    func isSubCategorySelected(_ name: String) -> Bool {
        subCategories.contains { Self.normalized($0) == Self.normalized(name) }
    }

    var canAddSubCategory: Bool {
        subCategories.count < Self.maxSubCategories
    }

    /// Select or deselect one sub-category. Returns false (and changes
    /// nothing) when 3 are already selected.
    @discardableResult
    mutating func toggleSubCategory(_ name: String) -> Bool {
        if isSubCategorySelected(name) {
            subCategories.removeAll { Self.normalized($0) == Self.normalized(name) }
            return true
        }
        guard canAddSubCategory else { return false }
        subCategories.append(name)
        return true
    }

    var subCategoriesChanged: Bool {
        Set(subCategories.map(Self.normalized)) != Set(originalSubCategories.map(Self.normalized))
    }

    // MARK: - Type

    /// The type picker's entries: the shared list, plus the note's own type
    /// first when it isn't on the list (or "No type" when it has none).
    func typeChoices(from noteTypes: [String]) -> [NoteTypeChoice] {
        var choices = noteTypes.map { NoteTypeChoice(value: $0, label: $0) }
        if originalType.isEmpty {
            choices.insert(NoteTypeChoice(value: "", label: "No type"), at: 0)
        } else if !noteTypes.contains(where: { Self.normalized($0) == Self.normalized(originalType) }) {
            choices.insert(NoteTypeChoice(value: originalType, label: originalType), at: 0)
        }
        return choices
    }

    var typeChanged: Bool {
        !Self.normalized(noteType).isEmpty && Self.normalized(noteType) != Self.normalized(originalType)
    }

    // MARK: - Title and content

    var titleChanged: Bool {
        trimmedTitle != originalTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var contentChanged: Bool {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
            != originalContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isTitleValid: Bool { !trimmedTitle.isEmpty }

    var isContentSizeOK: Bool {
        content.trimmingCharacters(in: .whitespacesAndNewlines).utf8.count <= Self.maxContentBytes
    }

    // MARK: - Saving

    var hasChanges: Bool {
        titleChanged || contentChanged || categoryChanged || subCategoriesChanged || typeChanged
    }

    var canSave: Bool {
        hasChanges && isTitleValid && isContentSizeOK
    }

    /// The fields to send to /api/edit_note; nil means "leave unchanged".
    /// Sub-categories go with every category change, because a move that
    /// sends none clears them on the server.
    var changes: NoteEditChanges {
        NoteEditChanges(
            entries: contentChanged ? content : nil,
            title: titleChanged ? trimmedTitle : nil,
            categoryId: categoryChanged ? categoryId : nil,
            subCategories: (categoryChanged || subCategoriesChanged) ? subCategories : nil,
            type: typeChanged ? noteType : nil
        )
    }
}

struct NoteEditChanges: Equatable {
    var entries: String?
    var title: String?
    var categoryId: Int?
    var subCategories: [String]?
    var type: String?

    var isEmpty: Bool {
        entries == nil && title == nil && categoryId == nil && subCategories == nil && type == nil
    }
}
