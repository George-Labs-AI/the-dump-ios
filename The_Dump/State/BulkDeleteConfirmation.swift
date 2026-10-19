import Foundation

/// Bulk delete asks the user to type how many notes are selected, as the web
/// app does. Surrounding spaces are ignored; anything else must match exactly.
enum BulkDeleteConfirmation {
    static func matches(typed: String, count: Int) -> Bool {
        count > 0 && typed.trimmingCharacters(in: .whitespacesAndNewlines) == String(count)
    }
}
