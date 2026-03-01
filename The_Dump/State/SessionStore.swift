import Foundation
import SwiftUI
import Combine

@MainActor
class SessionStore: ObservableObject {
    @Published var items: [SessionItem] = []
    private var pollingTask: Task<Void, Never>?
    
    private let pollingInterval: Duration = .seconds(5)
    private let autoRemoveDelay: Duration = .seconds(6)
    
    func addItem(_ item: SessionItem) {
        withAnimation { items.insert(item, at: 0) }
    }
    
    func updateStatus(id: String, status: UploadStatus) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].status = status
    }
    
    func markUploading(id: String) {
        updateStatus(id: id, status: .uploading)
    }
    
    func markProcessing(id: String, fileUuid: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].fileUuid = fileUuid
        items[index].status = .processing
        startPollingIfNeeded()
    }
    
    func markFailed(id: String, error: String) {
        updateStatus(id: id, status: .failed(error: error))
    }
    
    func getItem(id: String) -> SessionItem? {
        items.first { $0.id == id }
    }
    
    func clear() {
        pollingTask?.cancel()
        pollingTask = nil
        items.removeAll()
    }
    
    // MARK: - Processing Status Polling
    
    private func startPollingIfNeeded() {
        guard pollingTask == nil else { return }
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: pollingInterval)
                guard !Task.isCancelled else { break }
                await pollProcessingStatus()
                
                let stillProcessing = items.contains { $0.status == .processing }
                if !stillProcessing { break }
            }
            pollingTask = nil
        }
    }
    
    private func pollProcessingStatus() async {
        let uuids = items
            .filter { $0.status == .processing }
            .compactMap { $0.fileUuid }
        guard !uuids.isEmpty else { return }
        
        do {
            let statuses = try await NotesService.shared.checkFileStatus(fileUuids: uuids)
            for status in statuses {
                guard let index = items.firstIndex(where: { $0.fileUuid == status.fileUuid }) else { continue }
                switch status.status {
                case "completed":
                    withAnimation {
                        items[index].status = .processed(
                            noteId: status.organizedNoteId ?? "",
                            title: status.title,
                            category: status.categoryName
                        )
                    }
                    scheduleAutoRemoval(id: items[index].id)
                case "failed":
                    withAnimation {
                        items[index].status = .failed(error: status.error ?? "Processing failed")
                    }
                default:
                    break
                }
            }
        } catch {
            // Polling failures are silent — will retry next cycle
        }
    }
    
    private func scheduleAutoRemoval(id: String) {
        Task {
            try? await Task.sleep(for: autoRemoveDelay)
            guard !Task.isCancelled else { return }
            withAnimation {
                items.removeAll { $0.id == id }
            }
        }
    }
}
