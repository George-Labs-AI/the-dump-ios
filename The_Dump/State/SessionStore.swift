import Foundation
import SwiftUI
import Combine

@MainActor
class SessionStore: ObservableObject {
    @Published var items: [SessionItem] = []
    
    func addItem(_ item: SessionItem) {
        items.insert(item, at: 0)
    }
    
    func updateStatus(id: String, status: UploadStatus) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].status = status
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
    }
}
