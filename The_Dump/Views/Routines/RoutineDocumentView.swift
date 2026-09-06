import SwiftUI

// One canon document, rendered as markdown blocks. Bodies can be very large
// (the index doc is ~217K chars), so the body is split into blocks off the
// main actor and rendered a page at a time in a LazyVStack; a sentinel at
// the end of the visible slice pulls in the next page as the user scrolls,
// and a "Show all" button skips straight to the end.

struct RoutineDocumentView: View {
    private let routineSlug: String
    private let documentSlug: String
    private let title: String
    @StateObject private var viewModel: RoutineDocumentViewModel
    @State private var selectedNoteID: String?
    @State private var showNote = false
    @State private var showRevisions = false

    init(routineSlug: String, documentSlug: String, title: String) {
        self.routineSlug = routineSlug
        self.documentSlug = documentSlug
        self.title = title
        _viewModel = StateObject(wrappedValue: RoutineDocumentViewModel(
            routineSlug: routineSlug,
            documentSlug: documentSlug,
            fallbackTitle: title
        ))
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            Group {
                if viewModel.isLoading && viewModel.document == nil {
                    ProgressView("Loading…")
                        .foregroundColor(Theme.textPrimary)
                } else if let error = viewModel.errorMessage, viewModel.document == nil {
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
                } else if let document = viewModel.document {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: Theme.spacingSMPlus) {
                            DocumentHeader(document: document)

                            ForEach(viewModel.visibleBlocks) { indexed in
                                MarkdownBlockView(block: indexed.block)
                            }

                            if viewModel.hasMore {
                                loadMoreFooter
                            } else if viewModel.blocks.isEmpty {
                                Text("This document is empty.")
                                    .font(.system(size: Theme.fontSizeSM))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .padding(Theme.spacingLG)
                    }
                    // Second gate on links: only http(s) leaves the app, and
                    // the runner's note token opens NoteDetailView in place.
                    .environment(\.openURL, OpenURLAction { url in
                        if let noteID = MarkdownBlockParser.noteID(from: url) {
                            selectedNoteID = noteID
                            showNote = true
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
        .navigationTitle(viewModel.document?.title ?? title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let document = viewModel.document {
                    Menu {
                        if viewModel.hasMore {
                            Button {
                                viewModel.showAll()
                            } label: {
                                Label("Show entire document", systemImage: "arrow.down.to.line")
                            }
                        }
                        if let revisions = document.revisions, !revisions.isEmpty {
                            Button {
                                showRevisions = true
                            } label: {
                                Label("Revision history", systemImage: "clock.arrow.circlepath")
                            }
                        }
                        Button {
                            UIPasteboard.general.string = document.body
                        } label: {
                            Label("Copy markdown", systemImage: "doc.on.doc")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showNote) {
            if let selectedNoteID {
                NoteDetailView(noteID: selectedNoteID)
            }
        }
        .sheet(isPresented: $showRevisions) {
            if let document = viewModel.document {
                RevisionHistorySheet(document: document)
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var loadMoreFooter: some View {
        VStack(spacing: Theme.spacingSM) {
            // Sentinel: appearing near the end of the visible slice pulls in
            // the next page, so normal scrolling never hits a wall.
            Color.clear
                .frame(height: 1)
                .onAppear { viewModel.showMore() }

            Button {
                viewModel.showMore()
            } label: {
                Text("Show more (\(viewModel.remainingCount) more sections)")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())

            Button("Show entire document") {
                viewModel.showAll()
            }
            .font(.system(size: Theme.fontSizeSM))
            .foregroundColor(Theme.accent)
        }
        .padding(.top, Theme.spacingMD)
    }
}

private struct DocumentHeader: View {
    let document: RoutineDocument

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            HStack(spacing: Theme.spacingSM) {
                if let updated = RoutineDateParser.relative(document.updatedAt) {
                    MetaPill(text: "updated \(updated)", icon: "clock")
                }
                MetaPill(text: "rev \(document.revision)", icon: "number")
                if let kind = document.docKind?.trimmingCharacters(in: .whitespacesAndNewlines), !kind.isEmpty {
                    MetaPill(text: kind, icon: "tag")
                }
                Spacer()
            }

            if let summary = document.summary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
                Text(summary)
                    .font(.system(size: Theme.fontSizeSM))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Rectangle()
                .fill(Theme.borderLight)
                .frame(height: 1)
        }
        .padding(.bottom, Theme.spacingXS)
    }
}

private struct MetaPill: View {
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: Theme.spacingXS) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: Theme.fontSizeXS))
        }
        .foregroundColor(Theme.textSecondary)
        .padding(.horizontal, Theme.spacingSM)
        .padding(.vertical, Theme.spacingXS)
        .background(Theme.surface)
        .cornerRadius(Theme.cornerRadius)
    }
}

private struct RevisionHistorySheet: View {
    let document: RoutineDocument
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                List {
                    Section {
                        ForEach(document.revisions ?? []) { rev in
                            HStack {
                                Text("rev \(rev.revision)")
                                    .font(.system(size: Theme.fontSizeMD, weight: rev.revision == document.revision ? .semibold : .regular))
                                    .foregroundColor(Theme.textPrimary)
                                Spacer()
                                Text(RoutineDateParser.relative(rev.createdAt) ?? (rev.createdAt ?? ""))
                                    .font(.system(size: Theme.fontSizeSM))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    } header: {
                        Text("\(document.revisions?.count ?? 0) revisions")
                            .sectionLabel()
                            .foregroundColor(Theme.textSecondary)
                    }
                    .listRowBackground(Theme.surface)
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Revision History")
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
}

#Preview {
    NavigationStack {
        RoutineDocumentView(routineSlug: "example", documentSlug: "index", title: "Index")
    }
}
