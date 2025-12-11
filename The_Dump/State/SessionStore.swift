import Foundation
import SwiftUI
import Combine

@MainActor
class SessionStore: ObservableObject {
    @Published var items: [SessionItem] = []
    @Published var lastUploadStatus: String = ""
    
    func addItem(_ item: SessionItem) {
        items.insert(item, at: 0)
        updateLastStatus(for: item)
    }
    
    func updateStatus(id: String, status: UploadStatus) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].status = status
        updateLastStatus(for: items[index])
    }
    
    func markUploading(id: String) {
        updateStatus(id: id, status: .uploading)
    }
    
    func markSuccess(id: String, storagePath: String) {
        updateStatus(id: id, status: .success(storagePath: storagePath))
    }
    
    func markFailed(id: String, error: String) {
        updateStatus(id: id, status: .failed(error: error))
    }
    
    func getItem(id: String) -> SessionItem? {
        items.first { $0.id == id }
    }
    
    func clear() {
        items.removeAll()
        lastUploadStatus = ""
    }
    
    private func updateLastStatus(for item: SessionItem) {
        lastUploadStatus = item.status.displayText
    }
}
