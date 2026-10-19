import Foundation

/// One sub-category filter pill above a category's notes.
struct SubCategoryPill: Identifiable, Equatable {
    /// Shown on the pill and sent as sub_cat_name when it is tapped. The
    /// server matches it exactly (case included) against the names stored on
    /// notes, so this is the stored spelling whenever one is known.
    let name: String
    /// Notes with this sub-category, from /api/note_counts. The server counts
    /// by name across all categories, so two categories with a sub-category of
    /// the same name share one number. Nil when counts couldn't be loaded.
    let count: Int?

    var id: String { CategoryMapResponse.key(name) }
}

enum SubCategoryPills {
    /// Pills for `categoryName`: every active sub-category the category map
    /// lists (so a new, still-empty one shows up), plus any other name seen on
    /// the loaded notes (for example on an archived category, which the map
    /// leaves out). Names are matched ignoring case. The spelling kept is, in
    /// order: the one on this category's notes, the one the counts use, the
    /// one in the map (always lower-case).
    ///
    /// - Parameters:
    ///   - map: nil when /api/category_map couldn't be loaded; the pills then
    ///     come from the loaded notes only, as before.
    ///   - counts: /api/note_counts sub_categories, or nil when unavailable.
    ///   - namesOnNotes: sub-category names on the notes loaded in this category.
    ///   - added: names the user just created here, shown before the next reload.
    static func build(
        categoryName: String,
        map: CategoryMapResponse?,
        counts: [String: Int]?,
        namesOnNotes: [String],
        added: [String] = []
    ) -> [SubCategoryPill] {
        var spellingByKey: [String: String] = [:]

        func insert(_ raw: String, replacing: Bool) {
            let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            let key = CategoryMapResponse.key(name)
            if spellingByKey[key] == nil || replacing {
                spellingByKey[key] = name
            }
        }

        for name in map?.subCategories(forCategory: categoryName) ?? [] {
            insert(name, replacing: false)
        }
        for name in added {
            insert(name, replacing: false)
        }

        // The counts' spelling is what notes store; when the same name is
        // stored in two spellings, prefer the one more notes use.
        if let counts {
            for key in spellingByKey.keys {
                let best = counts
                    .filter { CategoryMapResponse.key($0.key) == key }
                    .max { lhs, rhs in
                        lhs.value != rhs.value ? lhs.value < rhs.value : lhs.key > rhs.key
                    }
                if let best {
                    spellingByKey[key] = best.key.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        for name in namesOnNotes {
            insert(name, replacing: true)
        }

        func count(for name: String) -> Int? {
            guard let counts else { return nil }
            return counts.first { $0.key.trimmingCharacters(in: .whitespacesAndNewlines) == name }?.value ?? 0
        }

        return spellingByKey.values
            .map { SubCategoryPill(name: $0, count: count(for: $0)) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

/// Bulk delete asks the user to type how many notes are selected, as the web
/// app does. Surrounding spaces are ignored; anything else must match exactly.
enum BulkDeleteConfirmation {
    static func matches(typed: String, count: Int) -> Bool {
        count > 0 && typed.trimmingCharacters(in: .whitespacesAndNewlines) == String(count)
    }
}
