import Foundation
import Combine

extension Notification.Name {
    /// Posted after a note is deleted from its own screen. userInfo["noteId"]
    /// is the deleted note's ID, so lists can drop it without reloading.
    static let noteWasDeleted = Notification.Name("noteWasDeleted")
}

@MainActor
final class NoteDetailViewModel: ObservableObject {
    @Published private(set) var note: NoteDetail?
    /// The note body split into markdown blocks for read mode.
    @Published private(set) var bodyBlocks: [IndexedMarkdownBlock] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isSaving: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoadingAsset: Bool = false
    @Published private(set) var assetResponse: NoteAssetResponse? = nil
    @Published var assetErrorMessage: String? = nil

    @Published private(set) var isEditing: Bool = false
    @Published var draft = NoteEditDraft()
    @Published private(set) var editOptions: NoteEditOptions = .empty
    @Published private(set) var isLoadingEditOptions: Bool = false
    @Published private(set) var editOptionsError: String?

    @Published private(set) var isDeleting: Bool = false
    @Published var deleteErrorMessage: String?

    private let noteID: String

    init(noteID: String) {
        self.noteID = noteID
    }

    func loadIfNeeded() async {
        guard note == nil else { return }
        await load()
    }

    func reload() async {
        note = nil
        bodyBlocks = []
        await load()
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let notes = try await NotesService.shared.fetchFullNote(ids: [noteID])
            if let loaded = notes.first {
                await show(loaded)
            } else {
                errorMessage = "Note not found."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Set the note together with its parsed body, so read mode never shows
    /// a loaded note with an empty body.
    private func show(_ loaded: NoteDetail) async {
        let body = loaded.note_content
        // A note can be up to 500 KB; parse off the main actor like routine
        // documents do.
        let blocks = await Task.detached(priority: .userInitiated) {
            MarkdownBlockParser.parse(body)
        }.value
        note = loaded
        bodyBlocks = blocks
    }

    // MARK: - Editing

    func beginEditing() {
        guard let note else { return }
        errorMessage = nil
        draft = NoteEditDraft(note: note, noteTypes: NoteTypeCatalog.shared.types)
        draft.adoptCategoryID(from: editOptions)
        isEditing = true
    }

    func cancelEditing() {
        errorMessage = nil
        isEditing = false
    }

    /// Load the category and sub-category choices (and the type list) for
    /// edit mode. Without categories the picker shows only the note's own
    /// category, and everything else can still be edited.
    func loadEditOptions() async {
        guard !isLoadingEditOptions else { return }
        isLoadingEditOptions = true
        editOptionsError = nil

        async let typesRefresh: Void = NoteTypeCatalog.shared.refresh()
        async let categoriesResponse = NotesService.shared.fetchCategories()
        async let mapResponse = NotesService.shared.fetchCategoryMap()

        do {
            let categories = try await categoriesResponse
            // Sub-categories are optional: the note's own still show without them.
            let map = try? await mapResponse
            editOptions = NoteEditOptions(categories: categories.categories, map: map)
            draft.adoptCategoryID(from: editOptions)
        } catch {
            editOptionsError = "Couldn't load your categories."
        }

        await typesRefresh
        isLoadingEditOptions = false
    }

    var categoryChoices: [NoteCategoryChoice] {
        draft.categoryChoices(from: editOptions)
    }

    var subCategoryChoices: [String] {
        draft.subCategoryChoices(from: editOptions)
    }

    func selectCategory(id: Int?) {
        guard let choice = categoryChoices.first(where: { $0.id == id }) else { return }
        draft.selectCategory(choice, availableSubCategories: editOptions.subCategories(forCategoryNamed: choice.name))
    }

    func toggleSubCategory(_ name: String) {
        draft.toggleSubCategory(name)
    }

    func saveEdits() async -> Bool {
        guard let currentNote = note else {
            errorMessage = "No note loaded."
            return false
        }

        guard !isSaving else { return false }
        errorMessage = nil

        guard draft.isTitleValid else {
            errorMessage = "Title is required."
            return false
        }

        let changes = draft.changes
        guard !changes.isEmpty else {
            isEditing = false
            return true
        }

        isSaving = true

        do {
            let updated = try await NotesService.shared.editNote(
                noteId: currentNote.organized_note_id,
                entries: changes.entries,
                title: changes.title,
                categoryId: changes.categoryId,
                subCategories: changes.subCategories,
                type: changes.type
            )

            await show(NoteDetail(
                organized_note_id: updated.organized_note_id,
                title: updated.title ?? changes.title ?? currentNote.title,
                note_content: updated.note_content ?? changes.entries ?? currentNote.note_content,
                note_content_modified: updated.note_content_modified ?? currentNote.note_content_modified,
                category_id: updated.category_id ?? currentNote.category_id,
                category_name: updated.category_name ?? currentNote.category_name,
                sub_cat_names: updated.sub_cat_names ?? currentNote.sub_cat_names,
                tags: currentNote.tags,
                mime_type: updated.mime_type ?? currentNote.mime_type,
                note_type: updated.note_type ?? currentNote.note_type,
                author: currentNote.author,
                has_asset: currentNote.has_asset
            ))

            isSaving = false
            isEditing = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
            return false
        }
    }

    // MARK: - Delete

    /// Delete the note for good. On success the caller leaves the screen and
    /// lists drop the note (see `.noteWasDeleted`).
    func deleteNote() async -> Bool {
        guard !isDeleting else { return false }
        isDeleting = true
        deleteErrorMessage = nil

        do {
            try await NotesService.shared.deleteNote(noteId: noteID)
            NotificationCenter.default.post(name: .noteWasDeleted, object: nil, userInfo: ["noteId": noteID])
            isDeleting = false
            return true
        } catch {
            deleteErrorMessage = error.localizedDescription
            isDeleting = false
            return false
        }
    }

    // MARK: - Original file

    /// Whether this note has an original file to open (photo, recording,
    /// document). Servers that don't send has_asset fall back to the old
    /// guess from the media type.
    var hasOriginalAsset: Bool {
        if let hasAsset = note?.has_asset { return hasAsset }
        let mt = note?.mime_type?.lowercased() ?? ""
        let nt = note?.note_type?.lowercased() ?? ""
        if mt.hasPrefix("image") || mt.hasPrefix("photo") || nt == "photo" { return true }
        if mt.hasPrefix("audio") || mt.hasPrefix("voice") || nt == "voice" { return true }
        return false
    }

    /// SF Symbol name for the original asset button based on mime type and note type.
    /// Same kinds as the web's card button: photo, recording, document, and a
    /// paperclip for anything else (typed and shared text).
    var assetIconName: String {
        let mt = note?.mime_type?.lowercased() ?? ""
        let nt = note?.note_type?.lowercased() ?? ""
        if mt.hasPrefix("image") || mt.hasPrefix("photo") || nt == "photo" { return "photo.on.rectangle" }
        if mt.hasPrefix("audio") || mt.hasPrefix("voice") || nt == "voice" { return "waveform" }
        if mt == "document" { return "doc" }
        return "paperclip"
    }

    /// Fetch the original asset signed URL on demand.
    func fetchOriginalAsset() async {
        guard !isLoadingAsset else { return }
        isLoadingAsset = true
        assetErrorMessage = nil
        assetResponse = nil

        do {
            let response = try await NotesService.shared.fetchNoteAsset(noteId: noteID)
            if let response {
                assetResponse = response
            } else {
                assetErrorMessage = "No original file available for this note."
            }
        } catch {
            assetErrorMessage = error.localizedDescription
        }

        isLoadingAsset = false
    }
}
