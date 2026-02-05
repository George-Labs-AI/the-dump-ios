import SwiftUI
import Combine

// Shows the full content of a single note

struct NoteDetailView: View {
    private let noteID: String
    @StateObject private var viewModel: NoteDetailViewModel
    @State private var showMetadataSheet = false
    @State private var isEditing = false
    @State private var draftTitle = ""
    @State private var draftContent = ""

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

                            if isEditing {
                                VStack(alignment: .leading, spacing: Theme.spacingSM) {
                                    Text("Title")
                                        .font(.system(size: Theme.fontSizeSM, weight: .semibold))
                                        .foregroundColor(Theme.textSecondary)

                                    TextField("Title", text: $draftTitle)
                                        .textInputAutocapitalization(.sentences)
                                        .disableAutocorrection(false)
                                        .padding(.vertical, Theme.spacingXS)

                                    if draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text("Title is required.")
                                            .font(.system(size: Theme.fontSizeXS))
                                            .foregroundColor(Theme.accent)
                                    }

                                    Text("Content")
                                        .font(.system(size: Theme.fontSizeSM, weight: .semibold))
                                        .foregroundColor(Theme.textSecondary)

                                    TextEditor(text: $draftContent)
                                        .font(.system(size: Theme.fontSizeMD))
                                        .foregroundColor(Theme.textPrimary)
                                        .frame(minHeight: 220)
                                        .padding(.vertical, Theme.spacingXS)
                                        .background(Color.clear)
                                        .scrollContentBackground(.hidden)
                                }
                            } else {
                                // Main content
                                Text(note.note_content)
                                    .font(.system(size: Theme.fontSizeMD))
                                    .foregroundColor(Theme.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }

                        }
                        .padding(Theme.spacingLG)
                    }
                    .onAppear {
                        hydrateDraft(from: note)
                    }
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
                if viewModel.note != nil && !isEditing {
                    Button {
                        showMetadataSheet = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                if viewModel.note != nil {
                    if isEditing {
                        Button("Cancel") {
                            cancelEdits()
                        }
                        .foregroundColor(Theme.textSecondary)

                        Button(viewModel.isSaving ? "Saving..." : "Save") {
                            Task {
                                let trimmedTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                let saved = await viewModel.saveEdits(
                                    title: trimmedTitle,
                                    content: draftContent
                                )
                                if saved {
                                    isEditing = false
                                }
                            }
                        }
                        .foregroundColor(Theme.accent)
                        .disabled(!canSave || viewModel.isSaving)
                    } else {
                        Button("Edit") {
                            toggleEditMode()
                        }
                        .foregroundColor(Theme.accent)
                    }
                }
            }
        }
        .sheet(isPresented: $showMetadataSheet) {
            if let note = viewModel.note {
                NoteMetadataSheet(note: note)
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .navigationTitle(navTitle)
    }

    private var canSave: Bool {
        guard let note = viewModel.note else { return false }
        let trimmedTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = draftContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalTitle = (note.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let originalContent = note.note_content.trimmingCharacters(in: .whitespacesAndNewlines)

        let contentChanged = trimmedContent != originalContent
        let titleChanged = trimmedTitle != originalTitle
        let hasChanges = contentChanged || titleChanged

        let contentSizeOK = trimmedContent.utf8.count <= 500 * 1024
        let titleValid = !trimmedTitle.isEmpty
        return hasChanges && contentSizeOK && titleValid
    }

    private func hydrateDraft(from note: NoteDetail) {
        if !isEditing {
            draftTitle = note.title ?? ""
            draftContent = note.note_content
        }
    }

    private func toggleEditMode() {
        guard let note = viewModel.note else { return }
        if isEditing {
            cancelEdits()
        } else {
            draftTitle = note.title ?? ""
            draftContent = note.note_content
            isEditing = true
        }
    }

    private func cancelEdits() {
        if let note = viewModel.note {
            draftTitle = note.title ?? ""
            draftContent = note.note_content
        }
        isEditing = false
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

// MARK: - Compact Metadata Header (inline, subtle)

private struct NoteMetadataHeader: View {
    let note: NoteDetail

    var body: some View {
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
    }

    private func formattedDate(_ iso: String) -> String? {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: iso) else { return nil }

        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .short
        return relative.localizedString(for: date, relativeTo: Date())
    }
}

private struct MetadataPill: View {
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: Theme.fontSizeXS))
        }
        .foregroundColor(Theme.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.darkGray)
        .cornerRadius(12)
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
                        .listRowBackground(Theme.darkGray)
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
                        .listRowBackground(Theme.darkGray)
                    }

                    // Tags
                    if let tags = note.tags, !tags.isEmpty {
                        Section("Tags") {
                            FlowLayout(spacing: 8) {
                                ForEach(tags, id: \.self) { tag in
                                    TagChip(text: tag)
                                }
                            }
                        }
                        .listRowBackground(Theme.darkGray)
                    }

                    // Details
                    Section("Details") {
                        if let mimeType = note.mime_type, !mimeType.isEmpty {
                            MetadataRow(label: "Type", value: friendlyMimeType(mimeType))
                        }

                        if let noteType = note.note_type, !noteType.isEmpty {
                            MetadataRow(label: "Note Type", value: noteType)
                        }

                        MetadataRow(label: "Modified", value: formattedFullDate(note.note_content_modified) ?? "Unknown")
                    }
                    .listRowBackground(Theme.darkGray)
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

    private func formattedFullDate(_ iso: String) -> String? {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: iso) else { return nil }

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

private struct TagChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: Theme.fontSizeSM))
            .foregroundColor(Theme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.mediumGray)
            .cornerRadius(14)
    }
}

// Simple flow layout for tags
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
