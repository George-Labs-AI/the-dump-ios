import SwiftUI

// One canon document with an optional interactive presentation and Markdown
// fallback. Markdown bodies can be very large
// (the index doc is ~217K chars), so the body is split into blocks off the
// main actor and rendered a page at a time in a LazyVStack; a sentinel at
// the end of the visible slice pulls in the next page as the user scrolls,
// and a "Show all" button skips straight to the end.

struct RoutineDocumentView: View {
    private let routineSlug: String
    private let documentSlug: String
    private let title: String
    private let backTitle: String
    @StateObject private var viewModel: RoutineDocumentViewModel
    @State private var selectedNoteID: String?
    @State private var showNote = false
    @State private var showText = false
    @State private var interactiveFailed = false

    init(routineSlug: String, documentSlug: String, title: String, backTitle: String = "Back") {
        self.routineSlug = routineSlug
        self.documentSlug = documentSlug
        self.title = title
        self.backTitle = backTitle
        _viewModel = StateObject(wrappedValue: RoutineDocumentViewModel(
            routineSlug: routineSlug,
            documentSlug: documentSlug,
            fallbackTitle: title
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            Group {
                if viewModel.isLoading && viewModel.document == nil {
                    Text("Loading…")
                        .tdBody()
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage, viewModel.document == nil {
                    VStack(spacing: Theme.spacingMD) {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.textPrimary)
                            .multilineTextAlignment(.center)

                        Button("Retry") {
                            Task { await viewModel.reload() }
                        }
                        .buttonStyle(TDPrimaryButtonStyle())
                    }
                    .padding(Theme.screenH)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let document = viewModel.document {
                    if let html = document.interactiveHTML, !html.isEmpty, !showText {
                        VStack(alignment: .leading, spacing: Theme.spacingMD) {
                            // Same gaps as the Text layout, so switching
                            // views doesn't move the control.
                            VStack(alignment: .leading, spacing: Theme.spacingSMPlus) {
                                DocumentHeader(document: document, summaryLineLimit: 3) {
                                    copyMarkdown(document)
                                }
                                presentationPicker
                            }
                            .padding(.horizontal, Theme.screenH)
                            .padding(.top, Theme.spacingSM)

                            InteractiveCanonView(html: html) {
                                interactiveFailed = true
                                showText = true
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: Theme.spacingSMPlus) {
                                DocumentHeader(document: document) {
                                    copyMarkdown(document)
                                }

                                if let html = document.interactiveHTML, !html.isEmpty {
                                    presentationPicker
                                }
                                if interactiveFailed {
                                    Text("The interactive view didn’t load. Here’s the text.")
                                        .tdCaption()
                                        .foregroundStyle(Theme.textSecondary)
                                }

                                ForEach(viewModel.visibleBlocks) { indexed in
                                    MarkdownBlockView(block: indexed.block)
                                }

                                if viewModel.hasMore {
                                    loadMoreFooter
                                } else if viewModel.blocks.isEmpty {
                                    Text("This document is empty.")
                                        .tdBody()
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                            .padding(.horizontal, Theme.screenH)
                            .padding(.top, Theme.spacingSM)
                            .padding(.bottom, Theme.spacingLG)
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
                    }
                } else {
                    Text("This document is empty.")
                        .tdBody()
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        // Hidden with the bar; names the screen for VoiceOver.
        .navigationTitle(viewModel.document?.title ?? title)
        .navigationDestination(isPresented: $showNote) {
            if let selectedNoteID {
                NoteDetailView(noteID: selectedNoteID, backTitle: viewModel.document?.title ?? title)
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    /// "‹ {routine}" and, for a long document, "•••" with "Show entire
    /// document".
    private var topBar: some View {
        TDTopBar(backTitle: backTitle) {
            if viewModel.document != nil, viewModel.hasMore {
                Menu {
                    Button {
                        viewModel.showAll()
                        showText = true
                    } label: {
                        Label("Show entire document", systemImage: "arrow.down.to.line")
                    }
                } label: {
                    TDMoreLabel()
                }
            }
        }
    }

    private func copyMarkdown(_ document: RoutineDocument) {
        UIPasteboard.general.string = document.body
    }

    private var presentationPicker: some View {
        TDSegmentedControl(
            options: [(value: false, label: "Interactive"), (value: true, label: "Text")],
            selection: $showText
        )
        .accessibilityLabel("Document view")
        .onChange(of: showText) { _, value in
            if !value { interactiveFailed = false }
        }
    }

    private var loadMoreFooter: some View {
        VStack(spacing: Theme.spacingSM) {
            // Sentinel: appearing near the end of the visible slice pulls in
            // the next page, so normal scrolling never hits a wall.
            Color.clear
                .frame(height: 1)
                .onAppear { viewModel.showMore() }

            Button("Show more (\(viewModel.remainingCount) more sections)") {
                viewModel.showMore()
            }
            .buttonStyle(TDTextLinkStyle(color: Theme.textPrimary, size: 16))

            Button("Show entire document") {
                viewModel.showAll()
            }
            .buttonStyle(TDTextLinkStyle(size: 16))
        }
        .padding(.top, Theme.spacingMD)
    }
}

/// The document's title as the screen headline, when it was updated (no
/// version number: it means nothing to the reader), Copy markdown, and the
/// runner's summary when it sent one.
private struct DocumentHeader: View {
    let document: RoutineDocument
    var summaryLineLimit: Int? = nil
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            Text(document.title)
                .tdHeadline()
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, Theme.spacingSM)

            HStack(spacing: Theme.spacingSMPlus) {
                if let updated = RoutineDateParser.relative(document.updatedAt) {
                    Text("Updated \(updated)")
                        .tdCaption()
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
                Button("Copy markdown", action: onCopy)
                    .buttonStyle(TDTextLinkStyle(size: 13))
            }

            if let summary = document.summary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
                Text(summary)
                    .tdBody()
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(summaryLineLimit)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

#Preview {
    NavigationStack {
        RoutineDocumentView(routineSlug: "example", documentSlug: "index", title: "Index", backTitle: "Example Routine")
    }
}
