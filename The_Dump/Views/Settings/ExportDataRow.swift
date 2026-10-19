import SwiftUI
import UIKit

/// Settings row "Export my data": downloads everything the account holds
/// (GET /export-data), saves it as a JSON file and opens the share sheet so
/// it can be saved to Files or sent on.
struct ExportDataRow: View {
    @State private var isExporting = false
    @State private var exportFile: ExportFile?
    @State private var errorMessage: String?

    var body: some View {
        Button {
            Task { await export() }
        } label: {
            HStack {
                Text("Export my data")
                    .foregroundColor(Theme.accent)
                Spacer()
                if isExporting {
                    ProgressView()
                }
            }
        }
        .disabled(isExporting)
        .sheet(item: $exportFile) { file in
            ActivityView(items: [file.url]) {
                exportFile = nil
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Export failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func export() async {
        isExporting = true
        defer { isExporting = false }

        do {
            let data = try await NotesService.shared.exportData()
            let url = try DataExport.saveToTemporaryFile(data)
            exportFile = ExportFile(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ExportFile: Identifiable {
    let url: URL
    var id: URL { url }
}

/// The system share sheet. `onFinish` runs once the chosen destination has
/// finished, or the person cancels, so the empty sheet closes too.
private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            onFinish()
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
