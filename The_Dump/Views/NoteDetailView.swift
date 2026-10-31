import SwiftUI
import UIKit

// Shows the full content of a single note (Paper, 04 Note). The title and
// body are edited in place and saved as you go; the category, sub-categories
// and type change from the Category sheet and the Move panel.

struct NoteDetailView: View {
    private let noteID: String
    /// The screen this one was opened from, shown in the top bar's back button.
    private let backTitle: String
    @StateObject private var viewModel: NoteDetailViewModel
    @ObservedObject private var noteTypes = NoteTypeCatalog.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var showOriginalAsset = false
    @State private var showAssetError = false
    @State private var showDeleteConfirmation = false
    @State private var showCategorySheet = false
    @State private var showMoveSheet = false
    @State private var linkedNoteID = ""
    @State private var showLinkedNote = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case title
        case body
    }

    init(noteID: String, backTitle: String = "Back") {
        self.noteID = noteID
        self.backTitle = backTitle
        _viewModel = StateObject(wrappedValue: NoteDetailViewModel(noteID: noteID))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            content
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showCategorySheet) {
            NoteCategorySheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showMoveSheet) {
            NoteMoveSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showOriginalAsset) {
            if let asset = viewModel.assetResponse {
                OriginalAssetView(asset: asset)
            }
        }
        .navigationDestination(isPresented: $showLinkedNote) {
            NoteDetailView(noteID: linkedNoteID, backTitle: viewModel.note.map(displayTitle(for:)) ?? "Back")
        }
        .onChange(of: viewModel.assetResponse) { _, newValue in
            if newValue != nil {
                showOriginalAsset = true
            }
        }
        .onChange(of: viewModel.assetErrorMessage) { _, newValue in
            if newValue != nil {
                showAssetError = true
            }
        }
        .onChange(of: viewModel.draft.title) { _, newValue in
            if newValue.contains(where: \.isNewline) {
                // Return in the wrapping title field adds a line break;
                // titles are one line, so it moves on to the body instead.
                viewModel.draft.title = String(newValue.map { $0.isNewline ? " " : $0 })
                focusedField = .body
                return // the change above calls this again
            }
            viewModel.textDidChange()
        }
        .onChange(of: scenePhase) { _, phase in
            // Save what's typed before iOS may end the app in the background.
            guard phase == .background, viewModel.isEditingText else { return }
            let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Save note")
            let model = viewModel
            Task {
                await model.savePendingTextNow()
                UIApplication.shared.endBackgroundTask(backgroundTask)
            }
        }
        .onChange(of: viewModel.draft.content) { _, _ in
            viewModel.textDidChange()
        }
        .alert("Original File", isPresented: $showAssetError) {
            Button("OK", role: .cancel) {
                viewModel.assetErrorMessage = nil
            }
        } message: {
            Text(viewModel.assetErrorMessage ?? "")
        }
        .alert("Delete this note?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    if await viewModel.deleteNote() {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert(
            "Couldn't Delete Note",
            isPresented: Binding(
                get: { viewModel.deleteErrorMessage != nil },
                set: { if !$0 { viewModel.deleteErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.deleteErrorMessage ?? "")
        }
        .task {
            await viewModel.loadIfNeeded()
            // The categories bring each one's emoji for the chip, and the
            // choices for the Category sheet and Move panel.
            await viewModel.loadEditOptions()
        }
        .task(id: noteID) {
            // Opening a note counts as seeing it: clears its "+1" on Browse
            // and its Processing row on the Dump tab.
            await PendingNotesStore.shared.acknowledge(organizedNoteId: noteID)
        }
        .onDisappear {
            // Leaving mid-edit (the back button or a swipe) still saves; the
            // task keeps the model alive until it has saved or given up.
            if viewModel.isEditingText {
                let model = viewModel
                Task { await model.finishEditingOnLeave() }
            }
        }
    }

    // MARK: - Top bar

    /// "‹ Back" and "•••"; while editing, the save status and Done instead
    /// of "•••".
    private var topBar: some View {
        TDTopBar(backTitle: backTitle) {
            if viewModel.isEditingText {
                HStack(spacing: Theme.spacingMD) {
                    if let status = saveStatusText {
                        Text(status)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Button("Done") {
                        focusedField = nil
                        Task { await viewModel.finishEditingText() }
                    }
                    .buttonStyle(TDTextLinkStyle(color: Theme.textPrimary, size: 17))
                    .fontWeight(.medium)
                }
                .padding(.trailing, Theme.spacingXS)
            } else if viewModel.note != nil {
                Menu {
                    Button {
                        showMoveSheet = true
                    } label: {
                        Label("Move", systemImage: "folder")
                    }
                    Button {
                        if let note = viewModel.note {
                            UIPasteboard.general.string = note.note_content
                        }
                    } label: {
                        Label("Copy text", systemImage: "doc.on.doc")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete note", systemImage: "trash")
                    }
                    .disabled(viewModel.isDeleting)
                } label: {
                    TDMoreLabel()
                }
            }
        }
    }

    private var saveStatusText: String? {
        switch viewModel.saveState {
        case .idle: return nil
        case .saving: return "Saving…"
        case .saved: return "Saved"
        case .titleRequired: return "Title required"
        case .failed: return "Couldn't save"
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.note == nil {
            Text("Loading…")
                .tdCaption()
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(Theme.screenH)
        } else if let error = viewModel.errorMessage, viewModel.note == nil {
            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.system(size: Theme.fontSizeSM))
                    .foregroundColor(Theme.textPrimary)
                Button("Retry") {
                    Task { await viewModel.reload() }
                }
                .buttonStyle(TDTextLinkStyle(color: Theme.textPrimary, size: 16))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(Theme.screenH)
        } else if let note = viewModel.note {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    titleView(note)
                        .padding(.bottom, Theme.spacingSMPlus)

                    detailsLine(note)
                        .padding(.bottom, 20)

                    if let error = viewModel.errorMessage {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.system(size: Theme.fontSizeSM))
                            .foregroundColor(Theme.textPrimary)
                            .padding(.bottom, Theme.spacingMD)
                    }

                    bodyView

                    if !viewModel.isEditingText {
                        if viewModel.hasOriginalAsset {
                            originalFileRow(note)
                                .padding(.top, Theme.spacingSM)
                        }
                        detailsRows(note)
                            .padding(.top, Theme.spacingMD)
                        Button("Move") {
                            showMoveSheet = true
                        }
                        .buttonStyle(TDTextLinkStyle(color: Theme.textPrimary, size: 17))
                        .fontWeight(.medium)
                        .padding(.top, Theme.spacingSM)
                        .padding(.bottom, Theme.spacingLG)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.screenH)
                .padding(.top, Theme.spacingSM)
            }
            .scrollDismissesKeyboard(.interactively)
            // Links in the body: only http(s) leaves the app, and a note
            // link opens that note here.
            .environment(\.openURL, OpenURLAction { url in
                if let linkedID = MarkdownBlockParser.noteID(from: url) {
                    linkedNoteID = linkedID
                    showLinkedNote = true
                    return .handled
                }
                let scheme = url.scheme?.lowercased() ?? ""
                return (scheme == "http" || scheme == "https") ? .systemAction : .discarded
            })
        } else {
            Text("No content.")
                .tdCaption()
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(Theme.screenH)
        }
    }

    /// The title in Instrument Sans, exactly as stored. Tap it to edit.
    @ViewBuilder
    private func titleView(_ note: NoteDetail) -> some View {
        if viewModel.isEditingText {
            TextField("Title", text: $viewModel.draft.title, axis: .vertical)
                .font(.display(40))
                .tracking(40 * -0.04)
                .foregroundStyle(Theme.textPrimary)
                .focused($focusedField, equals: .title)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.next)
        } else {
            Text(displayTitle(for: note))
                .font(.display(40))
                .tracking(40 * -0.04)
                .lineHeight(.exact(points: 42))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.beginEditingText()
                    focusedField = .title
                }
                .accessibilityAddTraits([.isHeader, .isButton])
                .accessibilityHint("Edits the title")
        }
    }

    /// The category chip (tap to change it), then the type and the date the
    /// note was added, as plain text.
    private func detailsLine(_ note: NoteDetail) -> some View {
        HStack(spacing: Theme.spacingSM) {
            Button {
                showCategorySheet = true
            } label: {
                NoteCategoryChipLabel(emoji: categoryEmoji(note), name: categoryName(note))
            }
            .buttonStyle(TDPressStyle())
            .disabled(viewModel.isEditingText)
            .accessibilityLabel("Category: \(categoryName(note))")
            .accessibilityHint("Changes the category")

            let parts = [note.note_type, NoteDetailDates.short(note.note_content_modified)]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !parts.isEmpty {
                Text("· " + parts.joined(separator: " · "))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    /// The body, formatted; tap it to edit it as plain text (markdown).
    @ViewBuilder
    private var bodyView: some View {
        if viewModel.isEditingText {
            TextField("Note", text: $viewModel.draft.content, axis: .vertical)
                .font(.system(size: 16))
                .lineSpacing(5)
                .foregroundStyle(Theme.textPrimary)
                .focused($focusedField, equals: .body)
                .padding(.bottom, Theme.spacingXL)
        } else {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.bodyBlocks) { indexed in
                    MarkdownBlockView(block: indexed.block, style: .note)
                        .padding(.bottom, extraSpace(after: indexed.block))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.beginEditingText()
                focusedField = .body
            }
            .accessibilityHint("Double-tap to edit the note")
        }
    }

    /// Blocks the note style doesn't space itself.
    private func extraSpace(after block: MarkdownBlock) -> CGFloat {
        switch block {
        case .code, .table, .quote, .rule: return Theme.spacingMD
        default: return 0
        }
    }

    /// "View original photo", "Play original recording" or "Open original
    /// file", only on notes with an original file.
    private func originalFileRow(_ note: NoteDetail) -> some View {
        Button {
            Task { await viewModel.fetchOriginalAsset() }
        } label: {
            HStack(spacing: Theme.spacingSMPlus) {
                Image(systemName: originalFileSymbol(note))
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 18, height: 18)
                Text(originalFileLabel(note))
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if viewModel.isLoadingAsset {
                    Text("Opening…")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 16, height: 16)
                }
            }
            .padding(.horizontal, Theme.spacingMD)
            .frame(height: 52)
            .background(RoundedRectangle(cornerRadius: Theme.radiusInput).fill(Theme.surface))
            .contentShape(Rectangle())
        }
        .buttonStyle(TDPressStyle())
        .disabled(viewModel.isLoadingAsset)
    }

    private func originalFileKind(_ note: NoteDetail) -> OriginalFileKind {
        let mime = note.mime_type?.lowercased() ?? ""
        let type = note.note_type?.lowercased() ?? ""
        if mime.hasPrefix("image") || mime.hasPrefix("photo") || type == "photo" { return .image }
        if mime.hasPrefix("audio") || mime.hasPrefix("voice") || type == "voice" { return .voice }
        return OriginalFileKind(mimeType: note.mime_type)
    }

    private func originalFileLabel(_ note: NoteDetail) -> String {
        switch originalFileKind(note) {
        case .image: return "View original photo"
        case .voice: return "Play original recording"
        case .document, .text: return "Open original file"
        }
    }

    private func originalFileSymbol(_ note: NoteDetail) -> String {
        switch originalFileKind(note) {
        case .image: return "photo"
        case .voice: return "mic"
        case .document, .text: return "doc"
        }
    }

    /// The details at the bottom of the note: label on the left (104pt),
    /// value on the right, hairlines between. "Modified" is left out: the
    /// server doesn't send when a note was last edited.
    private func detailsRows(_ note: NoteDetail) -> some View {
        VStack(spacing: 0) {
            detailsRow("Category") {
                Button {
                    showCategorySheet = true
                } label: {
                    NoteCategoryChipLabel(emoji: categoryEmoji(note), name: categoryName(note))
                }
                .buttonStyle(TDPressStyle())
                .accessibilityHint("Changes the category")
            }
            TDHairline()
            detailsRow("Sub-categories") {
                let names = (note.sub_cat_names ?? []).filter { !$0.isEmpty }
                Text(names.isEmpty ? "None" : names.joined(separator: ", "))
                    .font(.system(size: 13))
                    .foregroundStyle(names.isEmpty ? Theme.textSecondary : Theme.textPrimary)
            }
            TDHairline()
            detailsRow("Type") {
                Text(note.note_type?.isEmpty == false ? note.note_type ?? "" : "None")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textPrimary)
            }
            TDHairline()
            if let author = note.author?.trimmingCharacters(in: .whitespacesAndNewlines), !author.isEmpty {
                detailsRow("From") {
                    Text(author)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textPrimary)
                }
                TDHairline()
            }
            detailsRow("Added") {
                Text(NoteDetailDates.full(note.note_content_modified) ?? "Unknown")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textPrimary)
            }
            TDHairline()
        }
    }

    private func detailsRow<Value: View>(_ label: String, @ViewBuilder value: () -> Value) -> some View {
        HStack(spacing: Theme.spacingMD) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 104, alignment: .leading)
            value()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 48)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Helpers

    private func categoryName(_ note: NoteDetail) -> String {
        let name = note.category_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "No category" : name
    }

    private func categoryEmoji(_ note: NoteDetail) -> String? {
        note.category_id.flatMap { viewModel.categoryEmojis[$0] }
    }

    private func displayTitle(for note: NoteDetail) -> String {
        if let title = note.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }

        let lines = note.note_content
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return lines.first ?? "Note"
    }
}

/// The category chip on a note: its emoji (or the grey folder), its name and
/// a small chevron, on the raised tone with 8pt corners.
struct NoteCategoryChipLabel: View {
    let emoji: String?
    let name: String

    var body: some View {
        HStack(spacing: Theme.spacingXS) {
            CategoryGlyph(emoji: emoji, size: 14)
            Text(name)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, Theme.spacingSM)
        .frame(height: 28)
        .background(RoundedRectangle(cornerRadius: Theme.radiusTag).fill(Theme.raised))
    }
}

/// The dates on a note's screen. The server sends when the note was added;
/// it doesn't send when it was last edited.
enum NoteDetailDates {
    /// "Oct 30", or "Oct 30, 2025" when it isn't this year.
    static func short(_ raw: String) -> String? {
        guard let date = NoteDates.parse(raw) else { return nil }
        let formatter = DateFormatter()
        let thisYear = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
        formatter.setLocalizedDateFormatFromTemplate(thisYear ? "MMM d" : "MMM d, yyyy")
        return formatter.string(from: date)
    }

    /// "Oct 30, 2026, 9:12 AM".
    static func full(_ raw: String) -> String? {
        guard let date = NoteDates.parse(raw) else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        NoteDetailView(noteID: "example-id")
    }
}
