import Foundation
import Combine

extension Notification.Name {
    static let categoryRecategorizationDidFinish = Notification.Name("categoryRecategorizationDidFinish")
}

@MainActor
final class CategoryRecategorizationTracker: ObservableObject {
    static let shared = CategoryRecategorizationTracker()

    struct Job: Codable, Equatable, Identifiable {
        let categoryId: Int
        let jobId: String
        var categoryName: String
        var noteCount: Int?
        var status: RecategorizeStatusValue
        var total: Int
        var processed: Int
        var moved: Int
        var skippedNoEmbeddings: Int
        var errors: Int
        var errorMessage: String?
        var createdAt: String?
        var startedAt: String?
        var completedAt: String?

        var id: Int { categoryId }
        var isActive: Bool { !status.isTerminal }
    }

    @Published private(set) var jobsByCategoryId: [Int: Job] = [:]

    var currentActiveJob: Job? {
        jobsByCategoryId.values
            .filter { $0.isActive }
            .sorted { lhs, rhs in
                if lhs.categoryName == rhs.categoryName {
                    return lhs.categoryId < rhs.categoryId
                }
                return lhs.categoryName.localizedCaseInsensitiveCompare(rhs.categoryName) == .orderedAscending
            }
            .first
    }

    private let storageKey = "categoryRecategorizationJobs.v1"
    private var hasLoadedPersistedJobs = false
    private var pollingEnabled = false
    private var pollTasks: [Int: Task<Void, Never>] = [:]

    private init() {}

    func bootstrap() {
        loadPersistedJobsIfNeeded()
        startPollingForActiveJobsIfNeeded()
    }

    func setPollingEnabled(_ enabled: Bool) {
        loadPersistedJobsIfNeeded()
        pollingEnabled = enabled

        if enabled {
            startPollingForActiveJobsIfNeeded()
        } else {
            cancelAllPolling()
        }
    }

    func clear() {
        cancelAllPolling()
        jobsByCategoryId.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    func startTracking(jobId: String, categoryId: Int, categoryName: String, noteCount: Int?) {
        loadPersistedJobsIfNeeded()

        jobsByCategoryId[categoryId] = Job(
            categoryId: categoryId,
            jobId: jobId,
            categoryName: categoryName,
            noteCount: noteCount,
            status: .pending,
            total: 0,
            processed: 0,
            moved: 0,
            skippedNoEmbeddings: 0,
            errors: 0,
            errorMessage: nil,
            createdAt: nil,
            startedAt: nil,
            completedAt: nil
        )
        persist()
        startPollingIfNeeded(for: categoryId)
    }

    func job(for categoryId: Int) -> Job? {
        loadPersistedJobsIfNeeded()
        return jobsByCategoryId[categoryId]
    }

    func isRecategorizing(categoryId: Int) -> Bool {
        job(for: categoryId)?.isActive == true
    }

    private func loadPersistedJobsIfNeeded() {
        guard !hasLoadedPersistedJobs else { return }
        hasLoadedPersistedJobs = true

        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }

        do {
            let decoded = try JSONDecoder().decode([Job].self, from: data)
            jobsByCategoryId = Dictionary(uniqueKeysWithValues: decoded.map { ($0.categoryId, $0) })
        } catch {
            UserDefaults.standard.removeObject(forKey: storageKey)
            jobsByCategoryId = [:]
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(Array(jobsByCategoryId.values))
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            #if DEBUG
            print("[CategoryRecategorizationTracker] Failed to persist jobs: \(error)")
            #endif
        }
    }

    private func startPollingForActiveJobsIfNeeded() {
        for (categoryId, job) in jobsByCategoryId where job.isActive {
            startPollingIfNeeded(for: categoryId)
        }
    }

    private func startPollingIfNeeded(for categoryId: Int) {
        guard pollingEnabled else { return }
        guard pollTasks[categoryId] == nil else { return }
        guard let job = jobsByCategoryId[categoryId], job.isActive else { return }

        pollTasks[categoryId] = Task { [weak self] in
            await self?.pollLoop(categoryId: categoryId, jobId: job.jobId)
        }
    }

    private func cancelAllPolling() {
        for task in pollTasks.values {
            task.cancel()
        }
        pollTasks.removeAll()
    }

    private func pollLoop(categoryId: Int, jobId: String) async {
        defer { pollTasks[categoryId] = nil }

        while pollingEnabled && !Task.isCancelled {
            do {
                let snapshot = try await NotesService.shared.fetchRecategorizeStatus(jobId: jobId)
                apply(snapshot, fallbackCategoryId: categoryId)
                if snapshot.status.isTerminal {
                    return
                }
            } catch {
                if Task.isCancelled { return }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                continue
            }

            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }
    }

    private func apply(_ snapshot: RecategorizeJobStatus, fallbackCategoryId: Int) {
        let categoryId = snapshot.scopeCategoryId ?? fallbackCategoryId
        var job = jobsByCategoryId[categoryId] ?? Job(
            categoryId: categoryId,
            jobId: snapshot.jobId,
            categoryName: "Category",
            noteCount: nil,
            status: snapshot.status,
            total: snapshot.total,
            processed: snapshot.processed,
            moved: snapshot.moved,
            skippedNoEmbeddings: snapshot.skippedNoEmbeddings,
            errors: snapshot.errors,
            errorMessage: snapshot.errorMessage,
            createdAt: snapshot.createdAt,
            startedAt: snapshot.startedAt,
            completedAt: snapshot.completedAt
        )

        job.status = snapshot.status
        job.total = snapshot.total
        job.processed = snapshot.processed
        job.moved = snapshot.moved
        job.skippedNoEmbeddings = snapshot.skippedNoEmbeddings
        job.errors = snapshot.errors
        job.errorMessage = snapshot.errorMessage
        job.createdAt = snapshot.createdAt
        job.startedAt = snapshot.startedAt
        job.completedAt = snapshot.completedAt

        if snapshot.status == .done {
            jobsByCategoryId.removeValue(forKey: categoryId)
            persist()
            NotificationCenter.default.post(
                name: .categoryRecategorizationDidFinish,
                object: nil,
                userInfo: ["categoryId": categoryId, "status": snapshot.status.rawValue]
            )
            return
        }

        jobsByCategoryId[categoryId] = job
        persist()

        if snapshot.status == .failed {
            NotificationCenter.default.post(
                name: .categoryRecategorizationDidFinish,
                object: nil,
                userInfo: ["categoryId": categoryId, "status": snapshot.status.rawValue]
            )
        }
    }
}
