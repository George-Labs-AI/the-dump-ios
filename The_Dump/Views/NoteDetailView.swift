import SwiftUI
import Combine

// Shows the full content of a single note

struct NoteDetailView: View {
    private let noteID: String
    @StateObject private var viewModel: NoteDetailViewModel
    @ObservedObject private var noteTypes = NoteTypeCatalog.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showMetadataSheet = false
    @State private var showOriginalAsset = false
    @State private var showAssetError = false
    @State private var showDeleteConfirmation = false
    @State private var linkedNoteID = ""
    @State private var showLinkedNote = false

    init(noteID: String) {
        self.noteID = noteID
        _viewModel = StateObject(wrappedValue: NoteDetailViewModel(noteID: noteID))
    }

    var body: some View {
        let navTitle = viewModel.note.map { displayTitle(for: $0) } ?? "Note"

        ZStack {
            Theme.background.ignoresSafeArea()

            Group {
                if viewModel.isLoading && viewModel.note == nil {
                    ProgressView("Loading…")
                        .foregroundColor(Theme.textPrimary)
                } else if let error = viewModel.errorMessage, viewModel.note == nil {
                    VStack(spacing: Theme.spacingMD) {
                        Text(error)
                            .font(.system(size: Theme.fontSizeSM))
                            .foregroundColor(Theme.accent)
                            .multilineTextAlignment(.center)

                        Button("Retry") {
                            Task { await viewModel.reload() }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(Theme.spacingLG)
                } else if let note = viewModel.note {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.spacingMD) {
                            // Compact metadata header
                            NoteMetadataHeader(note: note)

                            if viewModel.isEditing {
                                editForm
                            } else {
                                // Main content, formatted. Editing stays plain text.
                                LazyVStack(alignment: .leading, spacing: Theme.spacingSMPlus) {
                                    ForEach(viewModel.bodyBlocks) { indexed in
                                        MarkdownBlockView(block: indexed.block)
                                    }
                                }
                            }

                        }
                        .padding(Theme.spacingLG)
                    }
                    // Links in the body: only http(s) leaves the app, and a
                    // note link opens that note here.
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
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.note != nil && !viewModel.isEditing && viewModel.hasOriginalAsset {
                    Button {
                        Task { await viewModel.fetchOriginalAsset() }
                    } label: {
                        if viewModel.isLoadingAsset {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: viewModel.assetIconName)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .disabled(viewModel.isLoadingAsset)
                    .accessibilityLabel("View original")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.note != nil && !viewModel.isEditing {
                    Button {
                        showMetadataSheet = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundColor(Theme.textSecondary)
                    }
                    .accessibilityLabel("Note info")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.note != nil && !viewModel.isEditing {
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        if viewModel.isDeleting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "trash")
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .disabled(viewModel.isDeleting)
                    .accessibilityLabel("Delete note")
                }
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                if viewModel.note != nil {
                    if viewModel.isEditing {
                        Button("Cancel") {
                            viewModel.cancelEditing()
                        }
                        .foregroundColor(Theme.textSecondary)
                        .disabled(viewModel.isSaving)

                        Button(viewModel.isSaving ? "Saving..." : "Save") {
                            Task { _ = await viewModel.saveEdits() }
                        }
                        .foregroundColor(Theme.accent)
                        .disabled(!viewModel.draft.canSave || viewModel.isSaving)
                    } else {
                        Button("Edit") {
                            viewModel.beginEditing()
                            Task { await viewModel.loadEditOptions() }
                        }
                        .foregroundColor(Theme.accent)
                        .disabled(viewModel.isDeleting)
                    }
                }
            }
        }
        .sheet(isPresented: $showMetadataSheet) {
            if let note = viewModel.note {
                NoteMetadataSheet(note: note)
            }
        }
        .sheet(isPresented: $showOriginalAsset) {
            if let asset = viewModel.assetResponse {
                OriginalAssetView(asset: asset)
            }
        }
        .navigationDestination(isPresented: $showLinkedNote) {
            NoteDetailView(noteID: linkedNoteID)
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
        .alert("Original File", isPresented: $showAssetError) {
            Button("OK", role: .cancel) {
                viewModel.assetErrorMessage = nil
            }
        } message: {
            Text(viewModel.assetErrorMessage ?? "")
        }
        .alert("Delete Note", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    if await viewModel.deleteNote() {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this note? This action cannot be undone.")
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
        }
        .navigationTitle(navTitle)
    }

    // MARK: - Edit form

    private var editForm: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: Theme.fontSizeSM))
                    .foregroundColor(Theme.accent)
            }

            fieldLabel("Title")

            TextField("Title", text: $viewModel.draft.title)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(false)
                .padding(.vertical, Theme.spacingXS)

            if !viewModel.draft.isTitleValid {
                Text("Title is required.")
                    .font(.system(size: Theme.fontSizeXS))
                    .foregroundColor(Theme.accent)
            }

            categoryPicker
            subCategoryPicker
            typePicker

            fieldLabel("Content")

            TextEditor(text: $viewModel.draft.content)
                .font(.system(size: Theme.fontSizeMD))
                .foregroundColor(Theme.textPrimary)
                .frame(minHeight: 220)
                .padding(.vertical, Theme.spacingXS)
                .background(Color.clear)
                .scrollContentBackground(.hidden)

            if viewModel.draft.contentChanged && !viewModel.draft.isContentSizeOK {
                Text("This note is too long to save (500 KB at most).")
                    .font(.system(size: Theme.fontSizeXS))
                    .foregroundColor(Theme.accent)
            }
        }
        // A successful save replaces the draft with the server's copy, so
        // anything typed while saving would be lost.
        .disabled(viewModel.isSaving)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: Theme.fontSizeSM, weight: .semibold))
            .foregroundColor(Theme.textSecondary)
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: Theme.spacingXS) {
            HStack(spacing: Theme.spacingSM) {
                fieldLabel("Category")
                if viewModel.isLoadingEditOptions {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
                Picker(
                    "Category",
                    selection: Binding(
                        get: { viewModel.draft.categoryId },
                        set: { viewModel.selectCategory(id: $0) }
                    )
                ) {
                    ForEach(viewModel.categoryChoices, id: \.key) { choice in
                        Text(choice.label).tag(choice.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .tint(Theme.textPrimary)
            }

            if let error = viewModel.editOptionsError {
                HStack(spacing: Theme.spacingSM) {
                    Text(error)
                        .font(.system(size: Theme.fontSizeXS))
                        .foregroundColor(Theme.accent)
                    Button("Retry") {
                        Task { await viewModel.loadEditOptions() }
                    }
                    .font(.system(size: Theme.fontSizeXS, weight: .semibold))
                    .foregroundColor(Theme.accent)
                }
            }
        }
    }

    private var subCategoryPicker: some View {
        let choices = viewModel.subCategoryChoices
        let draft = viewModel.draft

        return VStack(alignment: .leading, spacing: Theme.spacingSM) {
            fieldLabel("Sub-categories")

            if choices.isEmpty {
                Text(viewModel.isLoadingEditOptions ? "Loading…" : "This category has no sub-categories.")
                    .font(.system(size: Theme.fontSizeXS))
                    .foregroundColor(Theme.textSecondary)
            } else {
                FlowLayout(spacing: Theme.spacingSM) {
                    ForEach(choices, id: \.self) { name in
                        let isSelected = draft.isSubCategorySelected(name)
                        SubCategoryChip(
                            text: name,
                            isSelected: isSelected,
                            isEnabled: isSelected || draft.canAddSubCategory
                        ) {
                            viewModel.toggleSubCategory(name)
                        }
                    }
                }

                Text("Choose up to \(NoteEditDraft.maxSubCategories).")
                    .font(.system(size: Theme.fontSizeXS))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.vertical, Theme.spacingXS)
    }

    private var typePicker: some View {
        HStack(spacing: Theme.spacingSM) {
            fieldLabel("Type")
            Spacer()
            Picker("Type", selection: $viewModel.draft.noteType) {
                ForEach(viewModel.draft.typeChoices(from: noteTypes.types), id: \.value) { choice in
                    Text(choice.label).tag(choice.value)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(Theme.textPrimary)
        }
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

// MARK: - Sub-category chip

private struct SubCategoryChip: View {
    let text: String
    let isSelected: Bool
    let isEnabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.spacingXS) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(text)
                    .font(.system(size: Theme.fontSizeSM, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? Theme.background : Theme.textPrimary)
            .padding(.horizontal, Theme.spacingSMPlus)
            .padding(.vertical, Theme.spacingSM)
            .background(isSelected ? Theme.textPrimary : Theme.surface2)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Compact Metadata Header (inline, subtle)

private struct NoteMetadataHeader: View {
    let note: NoteDetail

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            HStack(spacing: Theme.spacingSM) {
                // Category pill
                if let category = note.category_name, !category.isEmpty {
                    MetadataPill(text: category, icon: "folder")
                }

                // Date
                if let dateString = formattedDate(note.note_content_modified) {
                    MetadataPill(text: dateString, icon: "clock")
                }

                Spacer()
            }

            // Sender of an emailed note; the owner's own notes have none.
            if let author = note.author?.trimmingCharacters(in: .whitespacesAndNewlines), !author.isEmpty {
                MetadataPill(text: "from \(author)", icon: "envelope")
            }
        }
    }

    private func formattedDate(_ raw: String) -> String? {
        guard let date = NoteDates.parse(raw) else { return nil }

        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .short
        return relative.localizedString(for: date, relativeTo: Date())
    }
}

private struct MetadataPill: View {
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: Theme.spacingXS) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: Theme.fontSizeXS))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .foregroundColor(Theme.textSecondary)
        .padding(.horizontal, Theme.spacingSM)
        .padding(.vertical, Theme.spacingXS)
        .background(Theme.surface)
        .cornerRadius(Theme.cornerRadius)
    }
}

// MARK: - Full Metadata Sheet

private struct NoteMetadataSheet: View {
    let note: NoteDetail
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                List {
                    // Category
                    if let category = note.category_name, !category.isEmpty {
                        Section {
                            MetadataRow(label: "Category", value: category)
                        }
                        .listRowBackground(Theme.surface)
                    }

                    // Subcategories
                    if let subcats = note.sub_cat_names, !subcats.isEmpty {
                        Section("Subcategories") {
                            ForEach(subcats, id: \.self) { subcat in
                                Text(subcat)
                                    .font(.system(size: Theme.fontSizeMD))
                                    .foregroundColor(Theme.textPrimary)
                            }
                        }
                        .listRowBackground(Theme.surface)
                    }

                    // Details
                    Section("Details") {
                        if let author = note.author?.trimmingCharacters(in: .whitespacesAndNewlines), !author.isEmpty {
                            MetadataRow(label: "From", value: author)
                        }

                        if let mimeType = note.mime_type, !mimeType.isEmpty {
                            MetadataRow(label: "Type", value: friendlyMimeType(mimeType))
                        }

                        if let noteType = note.note_type, !noteType.isEmpty {
                            MetadataRow(label: "Note Type", value: noteType)
                        }

                        MetadataRow(label: "Modified", value: formattedFullDate(note.note_content_modified) ?? "Unknown")
                    }
                    .listRowBackground(Theme.surface)
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Note Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Theme.accent)
                }
            }
        }
    }

    private func friendlyMimeType(_ mime: String) -> String {
        switch mime.lowercased() {
        case let m where m.contains("image"): return "Image"
        case let m where m.contains("audio"): return "Audio"
        case let m where m.contains("video"): return "Video"
        case let m where m.contains("pdf"): return "PDF"
        case let m where m.contains("text"): return "Text"
        default: return mime
        }
    }

    private func formattedFullDate(_ raw: String) -> String? {
        guard let date = NoteDates.parse(raw) else { return nil }

        let out = DateFormatter()
        out.locale = .current
        out.dateStyle = .long
        out.timeStyle = .short
        return out.string(from: date)
    }
}

private struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: Theme.fontSizeMD))
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: Theme.fontSizeMD))
                .foregroundColor(Theme.textPrimary)
        }
    }
}

// Simple flow layout for chips (also used by onboarding)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

#Preview {
    NavigationStack {
        NoteDetailView(noteID: "example-id")
    }
}
