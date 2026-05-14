import Combine
import SwiftUI
import Combine

/// Lightweight harness for `/api/recategorize` + `/api/recategorize/status/<id>`.
/// Lives under Settings so we can smoke-test the job pipeline against a known
/// small slice of data (one category, ideally with one note) before wiring the
/// real "update categories" flow.
struct RecategorizeTestView: View {
    @StateObject private var viewModel = RecategorizeTestViewModel()
    @State private var selectedCategoryId: Int?
    @State private var selectedScope: RecategorizeScope = .category

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            List {
                // Scope picker
                Section {
                    Picker("Scope", selection: $selectedScope) {
                        Text("Category").tag(RecategorizeScope.category)
                        Text("Uncategorized").tag(RecategorizeScope.uncategorized)
                        Text("All notes").tag(RecategorizeScope.all)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Theme.surface)
                } header: {
                    Text("Scope")
                        .foregroundColor(Theme.textSecondary)
                } footer: {
                    Text(scopeFooter)
                        .font(.system(size: Theme.fontSizeXS))
                        .foregroundColor(Theme.textTertiary)
                }

                // Category picker (only when scope = category)
                if selectedScope == .category {
                    Section {
                        if viewModel.isLoadingCategories {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                Text("Loading categories…")
                                    .foregroundColor(Theme.textSecondary)
                                    .padding(.leading, Theme.spacingSM)
                            }
                            .listRowBackground(Theme.surface)
                        } else if let loadError = viewModel.loadError {
                            VStack(alignment: .leading, spacing: Theme.spacingXS) {
                                Text("Failed to load categories")
                                    .font(.system(size: Theme.fontSizeSM, weight: .semibold))
                                    .foregroundColor(.red)
                                Text(loadError)
                                    .font(.system(size: Theme.fontSizeSM))
                                    .foregroundColor(Theme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .listRowBackground(Theme.surface)
                        } else if viewModel.categories.isEmpty {
                            Text("No categories found.")
                                .foregroundColor(Theme.textSecondary)
                                .listRowBackground(Theme.surface)
                        } else {
                            ForEach(viewModel.categories) { item in
                                Button {
                                    selectedCategoryId = item.id
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.name)
                                                .foregroundColor(Theme.textPrimary)
                                            Text("\(item.noteCount) \(item.noteCount == 1 ? "note" : "notes")")
                                                .font(.system(size: Theme.fontSizeXS))
                                                .foregroundColor(Theme.textTertiary)
                                        }
                                        Spacer()
                                        if selectedCategoryId == item.id {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(Theme.accent)
                                        }
                                    }
                                }
                                .listRowBackground(Theme.surface)
                            }
                        }
                    } header: {
                        Text("Pick a category to re-route")
                            .foregroundColor(Theme.textSecondary)
                    } footer: {
                        Text("Tip: pick the category with the fewest notes for the cheapest test.")
                            .font(.system(size: Theme.fontSizeXS))
                            .foregroundColor(Theme.textTertiary)
                    }
                }

                // Run button
                Section {
                    Button {
                        runTest()
                    } label: {
                        HStack {
                            if viewModel.isRunning {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                Text("Running…")
                                    .padding(.leading, Theme.spacingSM)
                            } else {
                                Image(systemName: "play.fill")
                                Text("Run Test")
                            }
                            Spacer()
                        }
                        .foregroundColor(canRun ? Theme.accent : Theme.textTertiary)
                    }
                    .disabled(!canRun)
                    .listRowBackground(Theme.surface)
                }

                // Live status
                if viewModel.jobId != nil || viewModel.lastError != nil {
                    Section {
                        StatusRows(viewModel: viewModel)
                    } header: {
                        Text("Job Status")
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Recategorize Test")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await viewModel.loadCategories()
            // Default to the smallest non-empty category for a cheap test.
            if selectedCategoryId == nil {
                selectedCategoryId = viewModel.smallestNonEmptyCategoryId
            }
        }
        .onDisappear {
            viewModel.cancelPolling()
        }
    }

    private var canRun: Bool {
        guard !viewModel.isRunning else { return false }
        if selectedScope == .category {
            return selectedCategoryId != nil
        }
        return true
    }

    private var scopeFooter: String {
        switch selectedScope {
        case .category:
            return "Re-routes only notes currently in the selected category."
        case .uncategorized:
            return "Re-routes only notes with no category assigned."
        case .all:
            return "Re-routes every non-retired note. Heavy — avoid for a quick test."
        }
    }

    private func runTest() {
        viewModel.run(scope: selectedScope, categoryId: selectedCategoryId)
    }
}

// MARK: - Status rows

private struct StatusRows: View {
    @ObservedObject var viewModel: RecategorizeTestViewModel

    var body: some View {
        if let error = viewModel.lastError {
            VStack(alignment: .leading, spacing: Theme.spacingXS) {
                Text("Error")
                    .font(.system(size: Theme.fontSizeXS, weight: .semibold))
                    .foregroundColor(.red)
                Text(error)
                    .font(.system(size: Theme.fontSizeSM))
                    .foregroundColor(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .listRowBackground(Theme.surface)
        }

        if let jobId = viewModel.jobId {
            row(label: "Job ID", value: jobId, monospaced: true)
        }

        if let status = viewModel.status {
            row(label: "Status", value: status.status.rawValue)
            row(label: "Total", value: "\(status.total)")
            row(label: "Processed", value: "\(status.processed)")
            row(label: "Moved", value: "\(status.moved)")
            row(label: "Skipped (no embeddings)", value: "\(status.skippedNoEmbeddings)")
            row(label: "Errors", value: "\(status.errors)")
            if let message = status.errorMessage, !message.isEmpty {
                VStack(alignment: .leading, spacing: Theme.spacingXS) {
                    Text("Error message")
                        .font(.system(size: Theme.fontSizeXS, weight: .semibold))
                        .foregroundColor(.red)
                    Text(message)
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .listRowBackground(Theme.surface)
            }

            if status.status == .pending || status.status == .running {
                ProgressView(value: progressValue(status))
                    .tint(Theme.accent)
                    .listRowBackground(Theme.surface)
            }
        }
    }

    @ViewBuilder
    private func row(label: String, value: String, monospaced: Bool = false) -> some View {
        HStack {
            Text(label)
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value)
                .foregroundColor(Theme.textPrimary)
                .font(monospaced ? .system(size: Theme.fontSizeSM, design: .monospaced) : .system(size: Theme.fontSizeSM))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .listRowBackground(Theme.surface)
    }

    private func progressValue(_ status: RecategorizeJobStatus) -> Double {
        guard status.total > 0 else { return 0 }
        return min(1.0, Double(status.processed) / Double(status.total))
    }
}

// MARK: - View model

@MainActor
final class RecategorizeTestViewModel: ObservableObject {
    @Published private(set) var categories: [CategoryListItem] = []
    @Published private(set) var isLoadingCategories = false
    @Published private(set) var loadError: String?
    @Published private(set) var isRunning = false
    @Published private(set) var jobId: String?
    @Published private(set) var status: RecategorizeJobStatus?
    @Published private(set) var lastError: String?

    // Tracks the whole run — start + poll — so cancellation reaches the
    // request even if it lands during the start-phase await (before the poll
    // loop begins).
    private var runTask: Task<Void, Never>?

    var smallestNonEmptyCategoryId: Int? {
        categories
            .filter { $0.noteCount > 0 }
            .min(by: { $0.noteCount < $1.noteCount })?
            .id
    }

    func loadCategories() async {
        isLoadingCategories = true
        loadError = nil
        defer { isLoadingCategories = false }

        do {
            async let cats = NotesService.shared.fetchCategories()
            async let counts = NotesService.shared.fetchCounts()
            let (categoriesResponse, countsResponse) = try await (cats, counts)
            let countsByName = countsResponse.categories
            let currentCategoryNames = Set(categoriesResponse.categories.map(\.name))

            categories = categoriesResponse.categories
                .map {
                    CategoryListItem.make(
                        from: $0,
                        noteCount: CategoryCountStore.resolvedNoteCount(
                            for: $0,
                            countsByName: countsByName,
                            currentCategoryNames: currentCategoryNames
                        )
                    )
                }
                .filter { !$0.archived }
                .sorted { $0.noteCount < $1.noteCount }
        } catch {
            loadError = error.localizedDescription
        }
    }

    func run(scope: RecategorizeScope, categoryId: Int?) {
        guard !isRunning else { return }
        runTask?.cancel()
        isRunning = true
        lastError = nil
        jobId = nil
        status = nil

        runTask = Task { [weak self] in
            await self?.runLoop(scope: scope, categoryId: categoryId)
        }
    }

    func cancelPolling() {
        runTask?.cancel()
        runTask = nil
        isRunning = false
    }

    private func runLoop(scope: RecategorizeScope, categoryId: Int?) async {
        defer { isRunning = false }

        do {
            let response = try await NotesService.shared.startRecategorize(scope: scope, categoryId: categoryId)
            guard !Task.isCancelled else { return }
            jobId = response.jobId
            await pollLoop(jobId: response.jobId)
        } catch {
            if !Task.isCancelled {
                lastError = error.localizedDescription
            }
        }
    }

    private func pollLoop(jobId: String) async {
        while !Task.isCancelled {
            do {
                let snapshot = try await NotesService.shared.fetchRecategorizeStatus(jobId: jobId)
                status = snapshot
                if snapshot.status.isTerminal {
                    return
                }
            } catch {
                if !Task.isCancelled {
                    lastError = error.localizedDescription
                }
                return
            }

            // ~1.5s between polls per the iOS guidance.
            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }
    }
}

#Preview {
    NavigationStack {
        RecategorizeTestView()
    }
}
