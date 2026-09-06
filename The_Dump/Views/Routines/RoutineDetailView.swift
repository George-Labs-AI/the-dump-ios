import SwiftUI

// Routine home — "Needs You" (open asks preview) + the document list.
// Mirrors the web's /routines/<slug> page (plan §6.2).

struct RoutineDetailView: View {
    private let slug: String
    private let name: String
    @StateObject private var viewModel: RoutineDetailViewModel

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
                        Text(error)
                            .font(.system(size: Theme.fontSizeSM))
                            .foregroundColor(Theme.accent)
                            .multilineTextAlignment(.center)

                        Button("Retry") {
                            Task { await viewModel.load() }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(Theme.spacingLG)
                } else {
                    List {
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
        .task {
            await viewModel.loadIfNeeded()
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
            if viewModel.openAsks.isEmpty {
                HStack(spacing: Theme.spacingSM) {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(Theme.success)
                    Text("Nothing waiting on you.")
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(Theme.textSecondary)
                }
                .listRowBackground(Theme.surface)
            } else {
                ForEach(viewModel.openAsks.prefix(Self.askPreviewLimit)) { ask in
                    NavigationLink {
                        RoutineAsksView(routineSlug: slug, routineName: viewModel.routine?.name ?? name) { askID in
                            viewModel.removeAnswered(askID: askID)
                        }
                    } label: {
                        AskPreviewRow(ask: ask)
                    }
                    .listRowBackground(Theme.surface)
                }
            }

            NavigationLink {
                RoutineAsksView(routineSlug: slug, routineName: viewModel.routine?.name ?? name) { askID in
                            viewModel.removeAnswered(askID: askID)
                        }
            } label: {
                HStack {
                    Text(viewModel.openAsks.count > Self.askPreviewLimit
                         ? "Review all \(viewModel.openAsks.count)"
                         : "All asks")
                        .font(.system(size: Theme.fontSizeSM, weight: .medium))
                        .foregroundColor(Theme.accent)
                    Spacer()
                }
            }
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
                    Text("rev \(document.revision)")
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
