import SwiftUI

// Routine home, built to The Dump Design System: the routine's name and
// purpose first, then its health, what needs the owner (only when
// something does) and its documents. Pause and the runner instructions sit
// in the "•••" menu; the screen raises them as its one button only when
// they matter (before the first report, while not running, while paused).
// Mirrors the web's /routines/<slug> page (plan §6.2).

struct RoutineDetailView: View {
    private let slug: String
    private let name: String
    private let backTitle: String
    @StateObject private var viewModel: RoutineDetailViewModel
    // One destination owned by the screen, not by the preview rows: a row
    // vanishing after its ask is answered must not pop or recreate the
    // asks view that is presenting.
    @State private var showAsks = false
    @State private var showConnect = false

    private static let askPreviewLimit = 3

    init(slug: String, name: String, backTitle: String = "Routines") {
        self.slug = slug
        self.name = name
        self.backTitle = backTitle
        _viewModel = StateObject(wrappedValue: RoutineDetailViewModel(slug: slug))
    }

    private var routineName: String {
        viewModel.routine?.name ?? name
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            content
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showAsks) {
            RoutineAsksView(routineSlug: slug, routineName: routineName) { askID in
                viewModel.removeAnswered(askID: askID)
            }
            .toolbar(.visible, for: .navigationBar)
        }
        .navigationDestination(isPresented: $showConnect) {
            if let routine = viewModel.routine {
                RoutineConnectView(routine: RoutineConnectView.Routine(routine))
                    .toolbar(.visible, for: .navigationBar)
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    // MARK: - Top bar

    /// "‹ Routines" and "•••". The menu holds Pause / Resume, the runner
    /// instructions and past questions. As on the web, Pause / Resume only
    /// appears when the server sent a status the app can read, because
    /// without one the app can't tell which state it is in.
    private var topBar: some View {
        TDTopBar(backTitle: backTitle) {
            if let routine = viewModel.routine {
                Menu {
                    if let status = routine.status, RoutineStatusDisplay(status: status) != .hidden {
                        Button {
                            Task { await viewModel.setPaused(!status.isPaused) }
                        } label: {
                            Label(status.isPaused ? "Resume routine" : "Pause routine",
                                  systemImage: status.isPaused ? "play.circle" : "pause.circle")
                        }
                        // A reload finishing after the change would bring
                        // back the old status, so wait for it.
                        .disabled(viewModel.isUpdatingPause || viewModel.isLoading)
                    }
                    Button {
                        showConnect = true
                    } label: {
                        Label("Runner instructions", systemImage: "terminal")
                    }
                    Button {
                        showAsks = true
                    } label: {
                        Label("Past questions", systemImage: "clock.arrow.circlepath")
                    }
                } label: {
                    TDMoreLabel()
                }
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.routine == nil {
            Text("Loading…")
                .tdBody()
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.routine == nil {
            VStack(spacing: Theme.spacingMD) {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    Task { await viewModel.load() }
                }
                .buttonStyle(TDPrimaryButtonStyle())
            }
            .padding(Theme.screenH)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    needsYouSection
                    documentsSection
                    nothingNeedsYouLine
                }
                .padding(.horizontal, Theme.screenH)
                .padding(.top, Theme.spacingSM)
                .padding(.bottom, Theme.spacingLG)
            }
            .refreshable {
                await viewModel.load()
            }
            .safeAreaInset(edge: .bottom) {
                bottomAction
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(routineName)
                .tdHeadline()
                .foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, Theme.spacingMD)

            if let description = viewModel.routine?.description?.trimmingCharacters(in: .whitespacesAndNewlines),
               !description.isEmpty {
                Text(description)
                    .tdBody()
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.bottom, Theme.spacingMD)
            }

            if let routine = viewModel.routine {
                RoutineHealthLabel(status: routine.status)

                if routine.status?.isPaused == true {
                    Text("Your runner skips its runs until you resume.")
                        .tdCaption()
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.top, Theme.spacingSM)
                }
            }

            if let pauseError = viewModel.pauseErrorMessage {
                Label("Couldn't update: \(pauseError)", systemImage: "exclamationmark.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, Theme.spacingSM)
            }
        }
    }

    // MARK: - Needs you

    /// Shown only when something is waiting, or when the asks couldn't load
    /// (a failed load must never read as "nothing waiting").
    @ViewBuilder
    private var needsYouSection: some View {
        if !viewModel.openAsks.isEmpty || viewModel.asksErrorMessage != nil {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Theme.spacingSM) {
                    TDSectionLabel(title: "Needs you")
                    if !viewModel.openAsks.isEmpty {
                        NeedsYouCount(count: viewModel.openAsks.count)
                    }
                }
                .padding(.bottom, Theme.spacingXS)

                if let asksError = viewModel.asksErrorMessage {
                    Label(viewModel.openAsks.isEmpty
                          ? "Couldn't load questions: \(asksError)"
                          : "Couldn't refresh questions: \(asksError)",
                          systemImage: "exclamationmark.triangle")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.vertical, Theme.spacingSMPlus)
                }

                let preview = Array(viewModel.openAsks.prefix(Self.askPreviewLimit))
                ForEach(Array(preview.enumerated()), id: \.element.id) { index, ask in
                    Button {
                        showAsks = true
                    } label: {
                        AskPreviewRow(ask: ask)
                    }
                    .buttonStyle(TDPressStyle())
                    if index < preview.count - 1 {
                        TDHairline()
                    }
                }

                Button(viewModel.openAsks.count > Self.askPreviewLimit
                       ? "Review all \(viewModel.openAsks.count)"
                       : "Review all") {
                    showAsks = true
                }
                .buttonStyle(TDTextLinkStyle(color: Theme.textPrimary, size: 16))
            }
            .padding(.top, Theme.spacingXL)
        }
    }

    // MARK: - Documents

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TDSectionLabel(title: "Documents")
                .padding(.bottom, Theme.spacingXS)

            if viewModel.documents.isEmpty {
                Text(isWaitingForFirstReport
                     ? "Documents show up here after the first run."
                     : "No documents yet.")
                    .tdBody()
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, Theme.spacingSM)
            } else {
                let docs = viewModel.documents
                ForEach(Array(docs.enumerated()), id: \.element.id) { index, doc in
                    NavigationLink {
                        RoutineDocumentView(
                            routineSlug: slug,
                            documentSlug: doc.slug,
                            title: doc.title,
                            backTitle: routineName
                        )
                    } label: {
                        DocumentRow(document: doc)
                    }
                    .buttonStyle(TDPressStyle())
                    if index < docs.count - 1 {
                        TDHairline()
                    }
                }
            }
        }
        .padding(.top, Theme.spacingXL)
    }

    /// When nothing is waiting: one quiet line, with the way to past
    /// questions. Hidden while the asks failed to load.
    @ViewBuilder
    private var nothingNeedsYouLine: some View {
        if viewModel.routine != nil, viewModel.openAsks.isEmpty, viewModel.asksErrorMessage == nil {
            HStack {
                Text("Nothing needs you.")
                    .tdCaption()
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Button("Past questions") {
                    showAsks = true
                }
                .buttonStyle(TDTextLinkStyle(size: 13))
            }
            .padding(.top, Theme.spacingXL)
        }
    }

    // MARK: - The one button

    private var isWaitingForFirstReport: Bool {
        guard let status = viewModel.routine?.status, !status.isPaused else { return false }
        return RoutineHealth(status: status) == .unknown && !status.hasReport
    }

    /// The runner instructions get the screen's button before the first
    /// report and while the runner has gone quiet.
    private var needsRunner: Bool {
        guard let status = viewModel.routine?.status, !status.isPaused else { return false }
        return isWaitingForFirstReport || RoutineHealth(status: status) == .silent
    }

    @ViewBuilder
    private var bottomAction: some View {
        if let status = viewModel.routine?.status, status.isPaused {
            Button("Resume routine") {
                Task { await viewModel.setPaused(false) }
            }
            .buttonStyle(TDPrimaryButtonStyle())
            .disabled(viewModel.isUpdatingPause || viewModel.isLoading)
            .padding(.horizontal, Theme.screenH)
            .padding(.bottom, Theme.spacingMD)
            .background(Theme.background)
        } else if needsRunner {
            VStack(spacing: Theme.spacingSMPlus) {
                Text("Your routine runs on your own computer. Finish setup there.")
                    .tdCaption()
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Connect your runner") {
                    showConnect = true
                }
                .buttonStyle(TDPrimaryButtonStyle())
            }
            .padding(.horizontal, Theme.screenH)
            .padding(.bottom, Theme.spacingMD)
            .background(Theme.background)
        }
    }
}

// MARK: - Rows

private struct AskPreviewRow: View {
    let ask: RoutineAsk

    var body: some View {
        HStack(spacing: Theme.spacingSMPlus) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ask.title)
                    .tdBody()
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let rec = ask.recommendation?.trimmingCharacters(in: .whitespacesAndNewlines), !rec.isEmpty {
                    Text("Recommended: \(rec)")
                        .tdCaption()
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(minHeight: 48)
        .padding(.vertical, Theme.spacingSMPlus)
        .contentShape(Rectangle())
    }
}

private struct DocumentRow: View {
    let document: RoutineDocumentMeta

    var body: some View {
        HStack(spacing: Theme.spacingSMPlus) {
            VStack(alignment: .leading, spacing: 2) {
                Text(document.title)
                    .tdBody()
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                if let updated = RoutineDateParser.relative(document.updatedAt) {
                    Text("Updated \(updated)")
                        .tdCaption()
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(minHeight: 48)
        .padding(.vertical, Theme.spacingSMPlus)
        .contentShape(Rectangle())
    }
}

/// The solid count next to "Needs you": primary-text fill, black digits.
private struct NeedsYouCount: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.system(size: 13, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(Theme.background)
            .padding(.horizontal, Theme.spacingXS)
            .frame(minWidth: 20, minHeight: 20)
            .background(Capsule().fill(Theme.textPrimary))
            .accessibilityLabel(count == 1 ? "1 needs you" : "\(count) need you")
    }
}

#Preview {
    NavigationStack {
        RoutineDetailView(slug: "example", name: "Example Routine")
    }
}
