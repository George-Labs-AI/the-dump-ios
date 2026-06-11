import Foundation
import SwiftUI
import UserNotifications

/// Polls `POST /api/file_status` for the processing status of pending note
/// uploads (docs/note-status-contract.md, Phase 1) and applies the results to
/// `PendingNotesStore`.
///
/// Cadence (per contract): every 5s while any non-terminal record exists,
/// backing off to 30s after 5 minutes of continuous polling; stops entirely
/// when none remain. Polling restarts at the fast cadence on every new upload
/// (`noteUploaded()`) and on app foregrounding, and is suspended while the
/// app is in the background (`handleScenePhase(_:)`).
///
/// MainActor-isolated (same shape as `CategoryRecategorizationTracker`): the
/// loop is a `Task`, so the main thread is never blocked — it only hops on to
/// flip lifecycle state between awaits.
@MainActor
final class NoteStatusService {
    static let shared = NoteStatusService()

    /// Contract cadence: 5s while fresh.
    static let fastPollInterval: TimeInterval = 5
    /// Contract cadence: 30s once polling has run for `backoffAfter`.
    static let slowPollInterval: TimeInterval = 30
    /// How long polling runs at the fast cadence before backing off.
    static let backoffAfter: TimeInterval = 5 * 60

    private let baseURL = "https://thedump.ai"
    private let store: PendingNotesStore

    private var pollTask: Task<Void, Never>?
    /// When the current polling run began — drives the 5s → 30s backoff.
    /// Reset on suspend and on new uploads so each restart begins fast.
    private var pollingStartedAt: Date?
    /// scenePhase != .background. Polling is allowed only in the foreground.
    private var isInForeground = false
    /// scenePhase == .active. Gates the "organized" local notification:
    /// it is only posted while the app is inactive/background.
    private var isAppActive = false
    /// Notification permission is requested lazily, the first time a poll
    /// cycle actually has records to ask about.
    private var hasRequestedNotificationAuthorization = false

    private init(store: PendingNotesStore = .shared) {
        self.store = store
    }

    // MARK: - Lifecycle triggers

    /// Wire this to the App's `.task` (initial phase) and
    /// `.onChange(of: scenePhase)`. Foreground (active/inactive) starts or
    /// resumes polling; background suspends it.
    func handleScenePhase(_ phase: ScenePhase) {
        isAppActive = phase == .active
        switch phase {
        case .background:
            isInForeground = false
            suspendPolling()
        default:
            isInForeground = true
            startPollingIfNeeded()
        }
    }

    /// Call after every successful upload: restarts the loop at the fast
    /// cadence so the new record is picked up promptly.
    func noteUploaded() {
        pollTask?.cancel()
        pollTask = nil
        pollingStartedAt = nil
        startPollingIfNeeded()
    }

    // MARK: - Polling loop

    private func startPollingIfNeeded() {
        guard isInForeground, pollTask == nil else { return }
        pollTask = Task { [weak self] in
            await self?.pollLoop()
        }
    }

    private func suspendPolling() {
        pollTask?.cancel()
        pollTask = nil
        pollingStartedAt = nil
    }

    private func pollLoop() async {
        while !Task.isCancelled {
            let pending = await store.nonTerminalRecords()
            guard !pending.isEmpty else {
                // Nothing left to track — stop entirely. `noteUploaded()` or
                // the next foregrounding starts a fresh loop.
                if !Task.isCancelled {
                    pollTask = nil
                    pollingStartedAt = nil
                }
                return
            }

            if pollingStartedAt == nil {
                pollingStartedAt = Date()
            }
            await requestNotificationAuthorizationIfNeeded()
            await pollOnce(fileUuids: pending.map(\.fileUuid))

            guard !Task.isCancelled else { return }
            try? await Task.sleep(nanoseconds: UInt64(currentPollInterval * 1_000_000_000))
        }
    }

    private var currentPollInterval: TimeInterval {
        guard let startedAt = pollingStartedAt else { return Self.fastPollInterval }
        let elapsed = Date().timeIntervalSince(startedAt)
        return elapsed >= Self.backoffAfter ? Self.slowPollInterval : Self.fastPollInterval
    }

    private func pollOnce(fileUuids: [String]) async {
        do {
            let response = try await fetchStatuses(fileUuids: fileUuids)
            await apply(response.statuses)
        } catch {
            // Transient (network blip, token refresh failure, 5xx) — keep
            // the cadence and try again on the next tick.
            #if DEBUG
            print("[NoteStatusService] Poll failed: \(error)")
            #endif
        }
    }

    private func apply(_ statuses: [FileStatusEntry]) async {
        for entry in statuses {
            guard let record = await store.record(fileUuid: entry.fileUuid) else { continue }
            let updated = NoteStatusMapping.apply(entry, to: record)
            guard updated != record else { continue }

            await store.update(fileUuid: entry.fileUuid) { current in
                current = NoteStatusMapping.apply(entry, to: current)
            }

            let becameOrganized = record.lifecycleStatus != .organized
                && updated.lifecycleStatus == .organized
            if becameOrganized && !isAppActive {
                await postOrganizedNotification(for: updated)
            }
        }
    }

    // MARK: - Networking

    private func fetchStatuses(fileUuids: [String]) async throws -> FileStatusResponse {
        let token = try await AuthService.shared.getIDToken()

        guard let url = URL(string: "\(baseURL)/api/file_status") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(FileStatusRequest(fileUuids: fileUuids))
        } catch {
            throw APIError.encodingFailed
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(underlying: URLError(.badServerResponse))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
                throw APIError.from(statusCode: httpResponse.statusCode, errorResponse: errorResponse)
            }

            return try JSONDecoder().decode(FileStatusResponse.self, from: data)
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingFailed(underlying: error)
        } catch {
            throw APIError.networkError(underlying: error)
        }
    }

    // MARK: - Local notifications

    private func requestNotificationAuthorizationIfNeeded() async {
        guard !hasRequestedNotificationAuthorization else { return }
        hasRequestedNotificationAuthorization = true

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    /// Posted when a record turns organized while the app is not active.
    /// Silently skipped if the user denied notification permission.
    private func postOrganizedNotification(for record: PendingNoteRecord) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let allowed = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
        guard allowed else { return }

        let content = UNMutableNotificationContent()
        if let title = record.title, !title.isEmpty {
            content.title = title
        } else {
            content.title = "Note organized"
        }
        if let category = record.categoryName, !category.isEmpty {
            content.body = "Note organized → \(category)"
        } else {
            content.body = "Your note has been organized."
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "note-organized-\(record.fileUuid)",
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }
}
