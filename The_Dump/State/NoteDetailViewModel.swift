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
    /// Each category's own emoji, by id, for the category chip and sheets.
    @Published private(set) var categoryEmojis: [Int: String] = [:]

    @Published private(set) var isDeleting: Bool = false
    @Published var deleteErrorMessage: String?

    /// What the top bar says while the title or body is being edited.
    enum SaveState: Equatable {
        case idle
        case saving
        case saved
        case titleRequired
        case failed
    }

    @Published private(set) var saveState: SaveState = .idle
    /// The title or body is being typed into (tap to edit, Done to finish).
    @Published private(set) var isEditingText: Bool = false

    private var autosaveTask: Task<Void, Never>?
    /// A change typed while a save was in flight; saved when it finishes.
    private var autosaveQueued = false
    private static let autosaveDelay: Duration = .milliseconds(800)
    private static let retryDelay: Duration = .seconds(5)

    private let noteID: String
    private var subCategoryObserver: NSObjectProtocol?

    init(noteID: String) {
        self.noteID = noteID

        // A sub-category renamed or deleted in Settings changes the names
        // stored on this note.
        subCategoryObserver = NotificationCenter.default.addObserver(
            forName: .subCategoriesDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let changed = SubCategoryChange.from(notification) else { return }
            Task { @MainActor [weak self] in
                await self?.subCategoriesDidChange(inCategory: changed.categoryId)
            }
        }
    }

    deinit {
        if let subCategoryObserver {
            NotificationCenter.default.removeObserver(subCategoryObserver)
        }
    }

    /// A sub-category of `categoryId` changed in Settings. If this note is in
    /// that category, show its current sub-categories without clearing the
    /// screen. While editing, only the choices are reloaded, so the user's
    /// unsaved changes stay.
    func subCategoriesDidChange(inCategory categoryId: Int) async {
        guard let note, note.category_id == categoryId else { return }
        if isEditing {
            await loadEditOptions()
            return
        }
        guard !isLoading, !isSaving,
              let loaded = try? await NotesService.shared.fetchFullNote(ids: [noteID]).first,
              !isEditing else { return }
        await show(loaded)
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
            categoryEmojis = Dictionary(
                categories.categories.compactMap { category in category.emoji.map { (category.categoryId, $0) } },
                uniquingKeysWith: { first, _ in first }
            )
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
                // Fields the reply leaves out (an emptied sub-category list
                // can come back as null) fall back to what was just sent,
                // then to the note as it was.
                category_id: updated.category_id ?? changes.categoryId ?? currentNote.category_id,
                category_name: updated.category_name
                    ?? (changes.categoryId != nil ? draft.categoryName : nil)
                    ?? currentNote.category_name,
                sub_cat_names: updated.sub_cat_names ?? changes.subCategories ?? currentNote.sub_cat_names,
                tags: currentNote.tags,
                mime_type: updated.mime_type ?? currentNote.mime_type,
                note_type: updated.note_type ?? changes.type ?? currentNote.note_type,
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

    // MARK: - Editing in place (Paper, 04 Note)

    /// Tap the title or body: edit it as plain text, saved as you go.
    func beginEditingText() {
        guard let note, !isEditingText else { return }
        errorMessage = nil
        if !isEditing {
            draft = NoteEditDraft(note: note, noteTypes: NoteTypeCatalog.shared.types)
        }
        isEditing = true
        isEditingText = true
        saveState = .idle
    }

    /// Called on every change to the title or body: save once typing pauses.
    func textDidChange() {
        guard isEditingText else { return }
        if !draft.isTitleValid {
            autosaveTask?.cancel()
            saveState = .titleRequired
            return
        }
        scheduleAutosave(after: Self.autosaveDelay)
    }

    /// Done: save what's left now, then show the note formatted again. If
    /// that save fails, or the title is empty, the text stays open so
    /// nothing typed is lost.
    func finishEditingText() async {
        autosaveTask?.cancel()
        if draft.titleChanged || draft.contentChanged {
            guard draft.isTitleValid else {
                saveState = .titleRequired
                return
            }
            // Let a save already in flight finish, then save the rest.
            while isSaving {
                try? await Task.sleep(for: .milliseconds(100))
            }
            if draft.titleChanged || draft.contentChanged {
                await autosave()
            }
            guard saveState != .failed else { return }
        }
        autosaveTask?.cancel()
        isEditingText = false
        isEditing = false
        saveState = .idle
        if let note { await show(note) }
    }

    private func scheduleAutosave(after delay: Duration) {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.autosave()
        }
    }

    /// Save the title and body as they are now. One save runs at a time;
    /// a change typed meanwhile is saved right after. A failure retries
    /// quietly a few seconds later. Like the Save button before it, a save
    /// replaces the server's copy, so an edit made elsewhere in the meantime
    /// is overwritten.
    private func autosave() async {
        guard let current = note, isEditingText else { return }
        guard draft.isTitleValid else {
            saveState = .titleRequired
            return
        }
        guard draft.titleChanged || draft.contentChanged else {
            if saveState == .saving { saveState = .saved }
            return
        }
        guard !draft.contentChanged || draft.isContentSizeOK else {
            saveState = .failed
            errorMessage = "This note is too long to save. Notes can be up to 500 KB."
            return
        }
        guard !isSaving else {
            autosaveQueued = true
            return
        }

        isSaving = true
        saveState = .saving
        let sentTitle = draft.titleChanged ? draft.trimmedTitle : nil
        let sentContent = draft.contentChanged ? draft.content : nil

        do {
            let updated = try await NotesService.shared.editNote(
                noteId: current.organized_note_id,
                entries: sentContent,
                title: sentTitle,
                categoryId: nil,
                subCategories: nil,
                type: nil
            )
            let saved = NoteDetail(
                organized_note_id: current.organized_note_id,
                title: updated.title ?? sentTitle ?? current.title,
                note_content: updated.note_content ?? sentContent ?? current.note_content,
                note_content_modified: current.note_content_modified,
                category_id: current.category_id,
                category_name: current.category_name,
                sub_cat_names: current.sub_cat_names,
                tags: current.tags,
                mime_type: current.mime_type,
                note_type: current.note_type,
                author: current.author,
                has_asset: current.has_asset
            )
            note = saved
            // What was just saved becomes the baseline; anything typed
            // during the save stays in the draft and is saved next.
            var rebased = NoteEditDraft(note: saved, noteTypes: NoteTypeCatalog.shared.types)
            rebased.title = draft.title
            rebased.content = draft.content
            draft = rebased
            errorMessage = nil
            isSaving = false
            saveState = .saved
            if autosaveQueued || draft.titleChanged || draft.contentChanged {
                autosaveQueued = false
                scheduleAutosave(after: .zero)
            }
        } catch {
            isSaving = false
            autosaveQueued = false
            saveState = .failed
            scheduleAutosave(after: Self.retryDelay)
        }
    }

    // MARK: - Move (category, sub-categories, type)

    /// Save a new category, sub-categories or type from the Category sheet or
    /// the Move panel. Nil leaves that part as it is. A move sends the
    /// sub-categories with it, because the server drops any the new category
    /// doesn't have and a move that sends none clears them all.
    func applyMove(category: NoteCategoryChoice?, subCategories: [String]?, type: String?) async -> Bool {
        guard let note else { return false }
        var moveDraft = NoteEditDraft(note: note, noteTypes: NoteTypeCatalog.shared.types)
        moveDraft.adoptCategoryID(from: editOptions)
        if let category {
            moveDraft.selectCategory(category, availableSubCategories: editOptions.subCategories(forCategoryNamed: category.name))
        }
        if let subCategories {
            moveDraft.setSubCategories(subCategories)
        }
        if let type {
            moveDraft.noteType = type
        }
        draft = moveDraft
        return await saveEdits()
    }

    /// The categories the note can move to: the active ones, plus its own
    /// even if that one has been archived.
    var moveCategoryChoices: [NoteCategoryChoice] {
        guard let note else { return [] }
        var fresh = NoteEditDraft(note: note, noteTypes: NoteTypeCatalog.shared.types)
        fresh.adoptCategoryID(from: editOptions)
        return fresh.categoryChoices(from: editOptions)
    }

    /// Sub-categories the note would lose by moving to `category`: the ones
    /// that category doesn't have, matched ignoring case. Empty until the
    /// category list has loaded, so the warning never guesses.
    func subCategoriesDropped(movingTo category: NoteCategoryChoice) -> [String] {
        guard editOptions.isLoaded, let note, category.id != note.category_id else { return [] }
        let kept = Set(editOptions.subCategories(forCategoryNamed: category.name).map(NoteEditDraft.normalized))
        return (note.sub_cat_names ?? []).filter { !kept.contains(NoteEditDraft.normalized($0)) }
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

    var hasOriginalAsset: Bool { Self.showsOriginalButton(for: note) }

    var assetIconName: String { Self.originalButtonIcon(for: note) }

    /// Whether to show the original-file button. Same rule as the web's
    /// Original buttons: every note the server says has an original file
    /// (has_asset), whatever its kind, and no others. Servers
    /// that don't send has_asset fall back to the old guess from the media
    /// type. A file missing from storage still answers "No original file
    /// available for this note."
    static func showsOriginalButton(for note: NoteDetail?) -> Bool {
        guard let note else { return false }
        if let hasAsset = note.has_asset { return hasAsset }
        let mt = note.mime_type?.lowercased() ?? ""
        let nt = note.note_type?.lowercased() ?? ""
        if mt.hasPrefix("image") || mt.hasPrefix("photo") || nt == "photo" { return true }
        if mt.hasPrefix("audio") || mt.hasPrefix("voice") || nt == "voice" { return true }
        return false
    }

    /// SF Symbol name for the original asset button. Same kinds as the web's
    /// card button: photo, recording, document, and a paperclip for anything
    /// else (typed and shared text). The app's older words for photos and
    /// recordings ("image", "photo", "voice" as the media or note type) are
    /// still recognised as well.
    static func originalButtonIcon(for note: NoteDetail?) -> String {
        let mt = note?.mime_type?.lowercased() ?? ""
        let nt = note?.note_type?.lowercased() ?? ""
        if mt.hasPrefix("image") || mt.hasPrefix("photo") || nt == "photo" { return "photo.on.rectangle" }
        if mt.hasPrefix("audio") || mt.hasPrefix("voice") || nt == "voice" { return "waveform" }
        switch OriginalFileKind(mimeType: note?.mime_type) {
        case .image: return "photo.on.rectangle"
        case .voice: return "waveform"
        case .document: return "doc"
        case .text: return "paperclip"
        }
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

/// The kind of a note's original file, worked out from its media type the
/// way the web does. The server stores either a real media type
/// ("image/png", "application/pdf") or a bare file extension ("heic",
/// "pdf"), so both forms are matched.
enum OriginalFileKind: Equatable {
    case image
    case voice
    case document
    case text

    init(mimeType: String?) {
        let mime = (mimeType ?? "").lowercased()
        func mentions(_ names: [String]) -> Bool { names.contains { mime.contains($0) } }
        if mime.hasPrefix("image/") || mentions(["heic", "heif", "jpg", "jpeg", "png", "gif", "tiff", "webp"]) {
            self = .image
        } else if mime.hasPrefix("audio/") || mentions(["m4a", "mp3", "wav", "aac", "ogg", "flac", "opus"]) {
            self = .voice
        } else if mime.hasPrefix("application/")
                    || (mime.hasPrefix("text/") && mime != "text/plain")
                    || mentions(["pdf", "doc", "xls", "ppt", "rtf", "csv"]) {
            self = .document
        } else {
            self = .text
        }
    }
}
