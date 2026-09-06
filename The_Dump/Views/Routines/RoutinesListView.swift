import SwiftUI

// All of the user's routines. Reached from the Routines row in Browse,
// which only appears when the user has at least one enabled routine.

struct RoutinesListView: View {
    @StateObject private var viewModel = RoutinesListViewModel()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            Group {
                if viewModel.isLoading && viewModel.routines.isEmpty {
                    ProgressView("Loading…")
                        .foregroundColor(Theme.textPrimary)
                } else if let error = viewModel.errorMessage, viewModel.routines.isEmpty {
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
                } else if viewModel.routines.isEmpty {
                    VStack(spacing: Theme.spacingMD) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 48))
                            .foregroundColor(Theme.textSecondary.opacity(0.5))
                        Text("No routines yet")
                            .font(.system(size: Theme.fontSizeLG, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)
                        Text("Routines keep living documents up to date from your notes.")
                            .font(.system(size: Theme.fontSizeSM))
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(Theme.spacingLG)
                } else {
                    List {
                        Section {
                            ForEach(viewModel.routines) { routine in
                                NavigationLink {
                                    RoutineDetailView(slug: routine.slug, name: routine.name)
                                } label: {
                                    RoutineRowView(routine: routine)
                                }
                                .listRowBackground(Theme.surface)
                            }
                        } header: {
                            Text("Routines")
                                .sectionLabel()
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await viewModel.load()
                    }
                }
            }
        }
        .navigationTitle("Routines")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await viewModel.loadIfNeeded()
        }
    }
}

private struct RoutineRowView: View {
    let routine: RoutineSummary

    var body: some View {
        HStack(spacing: Theme.spacingSMPlus) {
            Text("🔁")
                .font(.system(size: 18))
                .frame(width: 32, height: 32)
                .background(Theme.surface2)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusCatIcon))

            VStack(alignment: .leading, spacing: 2) {
                Text(routine.name)
                    .font(.system(size: Theme.fontSizeMD, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: Theme.spacingXS) {
                    let docs = routine.documentCount ?? 0
                    Text(docs == 1 ? "1 document" : "\(docs) documents")
                    if let updated = RoutineDateParser.relative(routine.updatedAt) {
                        Text("·")
                        Text("updated \(updated)")
                    }
                }
                .font(.system(size: Theme.fontSizeXS))
                .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            if let open = routine.openAskCount, open > 0 {
                OpenAskBadge(count: open)
            }
        }
        .padding(.vertical, Theme.spacingXS)
    }
}

/// "● 3" pill — the number of asks waiting on the user.
struct OpenAskBadge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.system(size: Theme.fontSizeXS, weight: .semibold))
            .foregroundColor(Theme.background)
            .padding(.horizontal, Theme.spacingSM)
            .padding(.vertical, 3)
            .background(Theme.accent)
            .clipShape(Capsule())
            .accessibilityLabel(count == 1 ? "1 open ask" : "\(count) open asks")
    }
}

#Preview {
    NavigationStack {
        RoutinesListView()
    }
}
