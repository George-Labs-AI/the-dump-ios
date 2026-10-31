import SwiftUI

// Routine home — "Needs You" (open asks preview) + the document list.
// Mirrors the web's /routines/<slug> page (plan §6.2).

struct RoutineDetailView: View {
    private let slug: String
    private let name: String
    @StateObject private var viewModel: RoutineDetailViewModel
    // One destination owned by the screen, not by the preview rows: a row
    // vanishing after its ask is answered must not pop or recreate the
    // asks view that is presenting.
    @State private var showAsks = false

    private static let askPreviewLimit = 3

    init(slug: String, name: String) {
        self.slug = slug
        self.name = name
        _viewModel = StateObject(wrappedValue: RoutineDetailViewModel(slug: slug))
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            Group {
                if viewModel.isLoading && viewModel.routine == nil {
                    ProgressView("Loading…")
                        .foregroundColor(Theme.textPrimary)
                } else if let error = viewModel.errorMessage, viewModel.routine == nil {
                    VStack(spacing: Theme.spacingMD) {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.system(size: Theme.fontSizeSM))
                            .foregroundColor(Theme.textPrimary)
                            .multilineTextAlignment(.center)

                        Button("Retry") {
                            Task { await viewModel.load() }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(Theme.spacingLG)
                } else {
                    List {
                        statusSection
                        headerSection
                        needsYouSection
                        documentsSection
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await viewModel.load()
                    }
                }
            }
        }
        .navigationTitle(viewModel.routine?.name ?? name)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationDestination(isPresented: $showAsks) {
            RoutineAsksView(routineSlug: slug, routineName: viewModel.routine?.name ?? name) { askID in
                viewModel.removeAnswered(askID: askID)
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    /// Health, Pause / Resume and the way back to the runner instructions.
    /// As on the web, Pause / Resume only appears when the server sent a
    /// status, because without one the app can't tell which state it is in.
    /// It is also left out for a status code the app can't read, which shows
    /// no status chip, so there is never a Pause button without a status.
    @ViewBuilder
    private var statusSection: some View {
        if let routine = viewModel.routine {
            Section {
                if RoutineStatusDisplay(status: routine.status) != .hidden {
                    HStack {
                        Text("Status")
                            .font(.system(size: Theme.fontSizeSM))
                            .foregroundColor(Theme.textSecondary)
                            // The chip's own spoken label already starts with "Status".
                            .accessibilityHidden(true)
                        Spacer()
                        RoutineHealthLabel(status: routine.status)
                    }
                }

                if let status = routine.status, RoutineStatusDisplay(status: status) != .hidden {
                    Button {
                        Task { await viewModel.setPaused(!status.isPaused) }
                    } label: {
                        HStack(spacing: Theme.spacingSM) {
                            Image(systemName: status.isPaused ? "play.circle" : "pause.circle")
                            Text(status.isPaused ? "Resume routine" : "Pause routine")
                            Spacer()
                            if viewModel.isUpdatingPause {
                                ProgressView()
                            }
                        }
                        .font(.system(size: Theme.fontSizeSM, weight: .medium))
                        .foregroundColor(Theme.accent)
                    }
                    .buttonStyle(.plain)
                    // A reload finishing after the change would bring back
                    // the old status, so wait for it.
                    .disabled(viewModel.isUpdatingPause || viewModel.isLoading)

                    if let pauseError = viewModel.pauseErrorMessage {
                        Label("Couldn't update: \(pauseError)", systemImage: "exclamationmark.circle")
                            .font(.system(size: Theme.fontSizeXS))
                            .foregroundColor(Theme.textPrimary)
                    }
                }

                NavigationLink {
                    RoutineConnectView(routine: RoutineConnectView.Routine(routine))
                } label: {
                    Text("Connect your runner")
                        .font(.system(size: Theme.fontSizeSM, weight: .medium))
                        .foregroundColor(Theme.textPrimary)
                }
            } footer: {
                if let status = routine.status, RoutineStatusDisplay(status: status) != .hidden {
                    Text("While a routine is paused, your runner is asked to skip its runs and The Dump stops warning you that it isn't running.")
                        .font(.system(size: Theme.fontSizeXS))
                        .foregroundColor(Theme.textTertiary)
                }
            }
            .listRowBackground(Theme.surface)
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        if let description = viewModel.routine?.description?.trimmingCharacters(in: .whitespacesAndNewlines),
           !description.isEmpty {
            Section {
                Text(description)
                    .font(.system(size: Theme.fontSizeSM))
                    .foregroundColor(Theme.textSecondary)
            }
            .listRowBackground(Theme.surface)
        }
    }

    private var needsYouSection: some View {
        Section {
            if let asksError = viewModel.asksErrorMessage {
                HStack(spacing: Theme.spacingSM) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(Theme.warning)
                    Text(viewModel.openAsks.isEmpty
                         ? "Couldn't load asks: \(asksError)"
                         : "Couldn't refresh asks: \(asksError)")
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(Theme.textSecondary)
                }
                .listRowBackground(Theme.surface)
            }

            if viewModel.openAsks.isEmpty {
                if viewModel.asksErrorMessage == nil {
                    HStack(spacing: Theme.spacingSM) {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(Theme.success)
                        Text("Nothing waiting on you.")
                            .font(.system(size: Theme.fontSizeSM))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .listRowBackground(Theme.surface)
                }
            } else {
                ForEach(viewModel.openAsks.prefix(Self.askPreviewLimit)) { ask in
                    Button {
                        showAsks = true
                    } label: {
                        HStack(spacing: Theme.spacingSM) {
                            AskPreviewRow(ask: ask)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: Theme.fontSizeSM, weight: .semibold))
                                .foregroundColor(Theme.textTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Theme.surface)
                }
            }

            Button {
                showAsks = true
            } label: {
                HStack {
                    Text(viewModel.openAsks.count > Self.askPreviewLimit
                         ? "Review all \(viewModel.openAsks.count)"
                         : "All asks")
                        .font(.system(size: Theme.fontSizeSM, weight: .medium))
                        .foregroundColor(Theme.accent)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: Theme.fontSizeSM, weight: .semibold))
                        .foregroundColor(Theme.textTertiary)
                }
            }
            .buttonStyle(.plain)
            .listRowBackground(Theme.surface)
        } header: {
            HStack {
                Text("Needs You")
                    .sectionLabel()
                    .foregroundColor(Theme.textSecondary)
                if !viewModel.openAsks.isEmpty {
                    OpenAskBadge(count: viewModel.openAsks.count)
                }
            }
        }
    }

    private var documentsSection: some View {
        Section {
            if viewModel.documents.isEmpty {
                Text("No documents published yet.")
                    .font(.system(size: Theme.fontSizeSM))
                    .foregroundColor(Theme.textSecondary)
                    .listRowBackground(Theme.surface)
            } else {
                ForEach(viewModel.documents) { doc in
                    NavigationLink {
                        RoutineDocumentView(routineSlug: slug, documentSlug: doc.slug, title: doc.title)
                    } label: {
                        DocumentRow(document: doc)
                    }
                    .listRowBackground(Theme.surface)
                }
            }
        } header: {
            Text("Documents")
                .sectionLabel()
                .foregroundColor(Theme.textSecondary)
        }
    }
}

private struct AskPreviewRow: View {
    let ask: RoutineAsk

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(ask.title)
                .font(.system(size: Theme.fontSizeMD, weight: .medium))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(2)

            HStack(spacing: Theme.spacingXS) {
                if let rec = ask.recommendation?.trimmingCharacters(in: .whitespacesAndNewlines), !rec.isEmpty {
                    Text("Recommended: \(rec)")
                        .lineLimit(1)
                }
                if let batch = ask.batchID, !batch.isEmpty {
                    Text("·")
                    Text(batch)
                        .lineLimit(1)
                }
            }
            .font(.system(size: Theme.fontSizeXS))
            .foregroundColor(Theme.textSecondary)
        }
        .padding(.vertical, Theme.spacingXS)
    }
}

private struct DocumentRow: View {
    let document: RoutineDocumentMeta

    var body: some View {
        HStack(spacing: Theme.spacingSMPlus) {
            Text("📄")
                .font(.system(size: 18))
                .frame(width: 32, height: 32)
                .background(Theme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusCatIcon))

            VStack(alignment: .leading, spacing: 2) {
                Text(document.title)
                    .font(.system(size: Theme.fontSizeMD, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: Theme.spacingXS) {
                    if let updated = RoutineDateParser.relative(document.updatedAt) {
                        Text("updated \(updated)")
                        Text("·")
                    }
                    Text("version \(document.revision)")
                }
                .font(.system(size: Theme.fontSizeXS))
                .foregroundColor(Theme.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, Theme.spacingXS)
    }
}

#Preview {
    NavigationStack {
        RoutineDetailView(slug: "example", name: "Example Routine")
    }
}
