import Foundation

// How a note row in a list describes itself.
extension NotePreview {
    /// The sender of an emailed note, or nil for the owner's own notes (the
    /// server sends null, and a blank value means the same).
    var displayAuthor: String? {
        guard let trimmed = author?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// True for a row that stands for a whole stack in a list fetched with
    /// stacks=1. Same rule as the web: a stack id plus more than one note.
    /// A stack's members carry its id but no counts, so they stay plain notes.
    var isStack: Bool {
        guard let stack_id, !stack_id.isEmpty else { return false }
        return (stack_total ?? stack_size ?? 1) > 1
    }

    /// "5 notes", or "2 of 5 notes" when the list's filters match only some
    /// of the stack. Nil for a plain note.
    var stackLabel: String? {
        guard isStack else { return nil }
        let total = stack_total ?? stack_size ?? 1
        let matching = stack_size ?? total
        return matching < total ? "\(matching) of \(total) notes" : "\(total) notes"
    }
}
