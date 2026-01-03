import SwiftUI
import Combine
import UniformTypeIdentifiers

//this is the view page that defines the other views
//learned that @ is not a decorator but a property wrapper
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var sessionStore = SessionStore()
    //@state makes sure what the variable is set to doesn't change just becuase the code reloads, and state is often used for things that a user may change
    @State private var showCamera = false
    @State private var showVoiceMemo = false
    @State private var showSettings = false
    @State private var showFilePicker = false
    @State private var showTextNote = false
    @State private var capturedImage: UIImage?
    
//a view is a type of struct that is called out as a view, and it must provide a body variable that contains the layout
    //"some" view is used to not have to tell the compiler the exact type name of what is in the view, since it would be too complex. There can only be one body property per View
    
    var body: some View {
        //navigation stack is like a history so the app remembers where you came from to populate values that rely on previos screen actions
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack {
                       Text("The Dump")
                           .font(.system(size: 18, weight: .semibold))
                           .foregroundColor(Theme.textPrimary)
                       
                       Spacer()
                       
                       Button(action: { showSettings = true }) {
                           Image(systemName: "gearshape")
                               .font(.system(size: 18))
                               .foregroundColor(Theme.textSecondary)
                               .padding(8)
                               .background(Theme.darkGray)
                               .clipShape(Circle())
                       }
                   }
                   .padding(.horizontal, Theme.spacingMD)
                   .padding(.top, Theme.spacingSM)
                   .padding(.bottom, Theme.spacingMD)
                    // Status bar
                    if !sessionStore.lastUploadStatus.isEmpty {
                        StatusBanner(text: sessionStore.lastUploadStatus)
                    }
                    // Main content
                    Text("You Dump, AI Organizes")
                        .font(.system(size: Theme.fontSizeLG))
                        .foregroundColor(Theme.textPrimary)
                        .padding()
                    Text("Visit \(Text("thedump.ai").foregroundColor(Theme.accent)) to see your organized notes")
                        .font(.system(size: Theme.fontSizeLG))
                        .foregroundColor(Theme.textPrimary)
                    ScrollView {
                        VStack(spacing: Theme.spacingLG) {
                            // Capture buttons
                            CaptureButtonsSection(
                                onPhotoTap: { showCamera = true },
                                onVoiceTap: { showVoiceMemo = true },
                                onFileTap: { showFilePicker = true },
                                onTextTap: { showTextNote = true }
                            )
                            .padding(.top, Theme.spacingLG)
                            
                            // Session history
                            SessionHistorySection(items: sessionStore.items)
                            
                            Spacer(minLength: Theme.spacingXL)
                        }
                        .padding(.horizontal, Theme.spacingMD)
                    }
                    .safeAreaInset(edge: .bottom){
                        AuthStatusFooter(email: appState.userEmail)
                            .padding()
                            .background(Theme.background)
                    }
                }
            }
            .navigationTitle("")
    .sheet(isPresented: $showCamera) {
            CameraView(image: $capturedImage)
        }
        .sheet(isPresented: $showVoiceMemo) {
            VoiceMemoView()
                .environmentObject(appState)
                .environmentObject(sessionStore)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(sessionStore)
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    handleSelectedFile(url)
                }
            case .failure(let error):
                sessionStore.lastUploadStatus = "File selection failed: \(error.localizedDescription)"
            }
        }
        .sheet(isPresented: $showTextNote) {
            TextNoteView()
                .environmentObject(appState)
                .environmentObject(sessionStore)
        }
        .onChange(of: capturedImage) { _, newImage in
            if let image = newImage {
                handleCapturedPhoto(image)
                capturedImage = nil
            }
        }
        .environmentObject(sessionStore)
    }
    }
    
    private func handleCapturedPhoto(_ image: UIImage) {
        Task {
            guard let email = appState.userEmail,
                  let idToken = await appState.idToken else {
                sessionStore.lastUploadStatus = "Not authenticated"
                return
            }
            
            // Create session item with thumbnail
            let thumbnailData = image.jpegData(compressionQuality: 0.3)
            let item = SessionItem(
                kind: .photo,
                originalFilename: "photo_\(UUID().uuidString).jpg",
                status: .uploading,
                thumbnailData: thumbnailData
            )
            
            sessionStore.addItem(item)
            
            do {
                let response = try await UploadService.shared.uploadPhoto(
                    image: image,
                    userEmail: email,
                    idToken: idToken
                )
                sessionStore.markSuccess(id: item.id, storagePath: response.storagePath)
            } catch {
                sessionStore.markFailed(id: item.id, error: error.localizedDescription)
            }
        }
    }

    private func handleSelectedFile(_ url: URL) {
        Task {
            guard let email = appState.userEmail,
                  let idToken = await appState.idToken else {
                sessionStore.lastUploadStatus = "Not authenticated"
                return
            }

            let item = SessionItem(
                kind: .file,
                originalFilename: url.lastPathComponent,
                localFileURL: url,
                status: .uploading
            )

            sessionStore.addItem(item)

            do {
                let response = try await UploadService.shared.uploadFile(
                    fileURL: url,
                    userEmail: email,
                    idToken: idToken
                )
                sessionStore.markSuccess(id: item.id, storagePath: response.storagePath)
            } catch {
                sessionStore.markFailed(id: item.id, error: error.localizedDescription)
            }
        }
    }
}

// MARK: - Subviews

struct StatusBanner: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: Theme.fontSizeSM))
            .foregroundColor(Theme.textPrimary)
            .padding(.vertical, Theme.spacingSM)
            .padding(.horizontal, Theme.spacingMD)
            .frame(maxWidth: .infinity)
            .background(Theme.darkGray)
    }
}

struct CaptureButtonsSection: View {
    let onPhotoTap: () -> Void
    let onVoiceTap: () -> Void
    let onFileTap: () -> Void
    let onTextTap: () -> Void

    var body: some View {
        VStack(spacing: Theme.spacingMD) {
            Text("Capture")
                .font(.system(size: Theme.fontSizeXS, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.spacingMD) {
                CaptureButton(
                    icon: "camera.fill",
                    label: "Photo",
                    action: onPhotoTap
                )

                CaptureButton(
                    icon: "mic.fill",
                    label: "Voice",
                    action: onVoiceTap
                )

                CaptureButton(
                    icon: "doc.fill",
                    label: "File",
                    action: onFileTap
                )

                CaptureButton(
                    icon: "keyboard",
                    label: "Note",
                    action: onTextTap
                )
            }
        }
    }
}

struct CaptureButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.spacingSM) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(Theme.accent)
                
                Text(label)
                    .font(.system(size: Theme.fontSizeSM, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.spacingLG)
            .background(Theme.darkGray)
            .cornerRadius(Theme.cornerRadius)
        }
    }
}

struct SessionHistorySection: View {
    let items: [SessionItem]
    
    var body: some View {
        VStack(spacing: Theme.spacingMD) {
            Text("Your Uploads This Session")
                .font(.system(size: Theme.fontSizeXS, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if items.isEmpty {
                VStack(spacing: Theme.spacingSM) {
                    Image(systemName: "tray")
                        .font(.system(size: 24))
                        .foregroundColor(Theme.textSecondary.opacity(0.5))
                    
                    Text("Nothing yet this session")
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.spacingXL)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius)
                        .strokeBorder(Theme.darkGray, style: StrokeStyle(lineWidth: 1, dash: [6]))
                )
            } else {
                LazyVStack(spacing: Theme.spacingSM) {
                    ForEach(items) { item in
                        SessionItemRow(item: item)
                    }
                }
            }
        }
    }
}

struct SessionItemRow: View {
    let item: SessionItem
    
    var body: some View {
        HStack(spacing: Theme.spacingMD) {
            // Thumbnail or icon
            Group {
                if let thumbnailData = item.thumbnailData,
                   let uiImage = UIImage(data: thumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSM))
                } else {
                    ZStack {
                        Theme.mediumGray
                        Image(systemName: iconForKind)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSM))
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(labelForKind)
                    .font(.system(size: Theme.fontSizeMD, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                
                Text(statusText)
                    .font(.system(size: Theme.fontSizeXS))
                    .foregroundColor(statusColor)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Status indicator
            statusIcon
        }
        .padding(Theme.spacingMD)
        .background(Theme.darkGray)
        .cornerRadius(Theme.cornerRadius)
    }
    
    private var iconForKind: String {
        switch item.kind {
        case .photo: return "photo"
        case .audio: return "waveform"
        case .file: return "doc"
        case .text: return "keyboard"
        }
    }

    private var labelForKind: String {
        switch item.kind {
        case .photo: return "Photo"
        case .audio: return "Voice Memo"
        case .file: return item.originalFilename
        case .text: return "Note"
        }
    }

    private var statusText: String {
        switch item.status {
        case .pending:
            return "Pending"
        case .uploading:
            return "Uploading…"
        case .success:
            return "Uploaded"
        case .failed(let error):
            return error
        }
    }
    
    private var statusColor: Color {
        switch item.status {
        case .success:
            return .green
        case .failed:
            return Theme.accent
        default:
            return Theme.textSecondary
        }
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch item.status {
        case .uploading:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.textSecondary))
                .scaleEffect(0.8)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(Theme.accent)
        case .pending:
            Image(systemName: "clock")
                .foregroundColor(Theme.textSecondary)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
