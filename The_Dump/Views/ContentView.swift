import SwiftUI
import Combine
import UniformTypeIdentifiers

// this is the view page that defines the other views
// learned that @ is not a decorator but a property wrapper
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var sessionStore = SessionStore()
    // @state makes sure what the variable is set to doesn't change just becuase the code reloads, and state is often used for things that a user may change
    @State private var showCamera = false
    @State private var showVoiceMemo = false
    @State private var showSettings = false
    @State private var showFilePicker = false
    @State private var showTextNote = false
    @State private var showPaywall = false
    @State private var capturedImage: UIImage?
    @State private var showErrorAlert = false
    @State private var errorAlertMessage = ""
    
// a view is a type of struct that is called out as a view, and it must provide a body variable that contains the layout
    // "some" view is used to not have to tell the compiler the exact type name of what is in the view, since it would be too complex. There can only be one body property per View
    
    var body: some View {
        // navigation stack is like a history so the app remembers where you came from to populate values that rely on previos screen actions
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack {
                       Text("The Dump")
                           .font(.system(size: Theme.fontSizeXL, weight: .bold))
                           .foregroundColor(Theme.textPrimary)
                       
                       Spacer()
                       
                       Button(action: { showSettings = true }, label: {
                           Image(systemName: "gearshape")
                               .font(.system(size: Theme.fontSizeLG))
                               .foregroundColor(Theme.textSecondary)
                               .padding(Theme.spacingSM)
                               .background(Theme.surface)
                               .clipShape(Circle())
                       })
                   }
                   .padding(.horizontal, Theme.spacingMD)
                   .padding(.top, Theme.spacingSM)
                   .padding(.bottom, Theme.spacingMD)
                    // Status bar (hidden while loading to avoid flash before real tier is known)
                    if appState.subscriptionViewModel.isBlocked && !appState.subscriptionViewModel.isLoading {
                        BlockedBanner(
                            reason: appState.subscriptionViewModel.usageStatus?.blockedReason,
                            onUpgradeTap: { showPaywall = true }
                        )
                    } else if appState.subscriptionViewModel.isBillingRetry {
                        BillingRetryBanner()
                    } else if appState.subscriptionViewModel.usagePercentage >= 80 {
                        UsageWarningBanner(label: appState.subscriptionViewModel.limitingFactorLabel)
                    }

                    // Main content
                    Text("Your brain dump, organized by AI.")
                        .font(.system(size: Theme.fontSizeLG))
                        .foregroundColor(Theme.textPrimary)
                        .padding()
                    ScrollView {
                        VStack(spacing: Theme.spacingLG) {
                            // Capture buttons
                            CaptureButtonsSection(
                                onPhotoTap: { guardCapture { showCamera = true } },
                                onVoiceTap: { guardCapture { showVoiceMemo = true } },
                                onFileTap: { guardCapture { showFilePicker = true } },
                                onTextTap: { guardCapture { showTextNote = true } }
                            )
                            .padding(.top, Theme.spacingLG)
                            
                            ForEach(sessionStore.items) { item in
                                SessionItemRow(item: item)
                            }

                            Spacer(minLength: Theme.spacingXL)
                        }
                        .padding(.horizontal, Theme.screenH)
                    }
                    .safeAreaInset(edge: .bottom) {
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
                errorAlertMessage = "File selection failed: \(error.localizedDescription)"
                showErrorAlert = true
            }
        }
        .sheet(isPresented: $showTextNote) {
            TextNoteView()
                .environmentObject(appState)
                .environmentObject(sessionStore)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(viewModel: appState.subscriptionViewModel)
        }
        .onChange(of: capturedImage) { _, newImage in
            if let image = newImage {
                handleCapturedPhoto(image)
                capturedImage = nil
            }
        }
        .environmentObject(sessionStore)
        .alert("Something went wrong", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorAlertMessage)
        }
    }
    }

    private func guardCapture(_ action: () -> Void) {
        if appState.subscriptionViewModel.isBlocked {
            showPaywall = true
        } else {
            action()
        }
    }
    
    private func handleCapturedPhoto(_ image: UIImage) {
        Task {
            guard let email = appState.userEmail,
                  let idToken = await appState.idToken else {
                errorAlertMessage = "Unable to upload. Please check your connection and try again."
                showErrorAlert = true
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
                _ = try await UploadService.shared.uploadPhoto(
                    image: image,
                    userEmail: email,
                    idToken: idToken
                )
                sessionStore.markCaptured(id: item.id)
            } catch {
                sessionStore.markFailed(id: item.id, error: error.localizedDescription)
            }
        }
    }

    private func handleSelectedFile(_ url: URL) {
        Task {
            guard let email = appState.userEmail,
                  let idToken = await appState.idToken else {
                errorAlertMessage = "Unable to upload. Please check your connection and try again."
                showErrorAlert = true
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
                _ = try await UploadService.shared.uploadFile(
                    fileURL: url,
                    userEmail: email,
                    idToken: idToken
                )
                sessionStore.markCaptured(id: item.id)
            } catch {
                sessionStore.markFailed(id: item.id, error: error.localizedDescription)
            }
        }
    }
}

// MARK: - Subviews

struct CaptureButtonsSection: View {
    let onPhotoTap: () -> Void
    let onVoiceTap: () -> Void
    let onFileTap: () -> Void
    let onTextTap: () -> Void

    var body: some View {
        VStack(spacing: Theme.spacingMD) {
            Text("Capture")
                .sectionLabel()
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.spacingMD) {
                CaptureButton(
                    emoji: "📸",
                    label: "Photo",
                    subLabel: "Take a photo",
                    action: onPhotoTap
                )

                CaptureButton(
                    emoji: "🎤",
                    label: "Voice",
                    subLabel: "Record audio",
                    action: onVoiceTap
                )

                CaptureButton(
                    emoji: "📄",
                    label: "File",
                    subLabel: "Upload file",
                    action: onFileTap
                )

                CaptureButton(
                    emoji: "✍️",
                    label: "Note",
                    subLabel: "Write text",
                    action: onTextTap
                )
            }

            CaptureHintNote(
                icon: "info.circle",
                message: "Videos and zip files aren't supported yet."
            )

            CaptureHintNote(
                icon: "square.and.arrow.up",
                message: "Saving an AI chat? Tap the share button in ChatGPT, Claude, or any other app and choose The Dump. Using Claude on your computer? Connect The Dump's MCP server to save conversations directly."
            )
        }
    }
}

struct CaptureHintNote: View {
    let icon: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.spacingSM) {
            Image(systemName: icon)
                .font(.system(size: Theme.fontSizeSM))
                .foregroundColor(Theme.textSecondary)

            Text(message)
                .font(.system(size: Theme.fontSizeXS))
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.spacingMD)
        .background(Theme.surface)
        .cornerRadius(Theme.cornerRadius)
    }
}

struct CaptureButton: View {
    let emoji: String
    let label: String
    let subLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.spacingSM) {
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.1))
                        .frame(width: 48, height: 48)

                    Text(emoji)
                        .font(.system(size: 22))
                }

                VStack(spacing: 2) {
                    Text(label)
                        .font(.system(size: Theme.fontSizeSM, weight: .medium))
                        .foregroundColor(Theme.textPrimary)

                    Text(subLabel)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.spacingXL)
            .background(Theme.surface)
            .cornerRadius(Theme.cornerRadiusCapture)
        }
    }
}

struct SessionItemRow: View {
    let item: SessionItem

    var body: some View {
        VStack(spacing: 0) {
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
                            Theme.surface2
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

            // Hint text for captured items
            if case .captured = item.status {
                Text("It'll show up in your notes in a few minutes.")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
            }
        }
        .padding(Theme.spacingMD)
        .background(Theme.surface)
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
        case .captured:
            return "Captured!"
        case .failed(let error):
            return error
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .captured:
            return Theme.success
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
            PulsingDot()
        case .captured:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Theme.success)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(Theme.accent)
        case .pending:
            Image(systemName: "clock")
                .foregroundColor(Theme.textSecondary)
        }
    }
}

struct PulsingDot: View {
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(Theme.accent)
            .frame(width: 10, height: 10)
            .opacity(isAnimating ? 0.3 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}

struct BlockedBanner: View {
    let reason: String?
    let onUpgradeTap: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Theme.warning)
            Text(reason ?? "You've reached your usage limit.")
                .font(.system(size: Theme.fontSizeSM))
                .foregroundColor(Theme.textPrimary)
            Spacer()
            Button("Upgrade") { onUpgradeTap() }
                .font(.system(size: Theme.fontSizeSM, weight: .semibold))
                .foregroundColor(Theme.accent)
        }
        .padding(.vertical, Theme.spacingSM)
        .padding(.horizontal, Theme.spacingMD)
        .background(Theme.accentSubtle)
    }
}

struct BillingRetryBanner: View {
    var body: some View {
        HStack {
            Image(systemName: "creditcard.trianglebadge.exclamationmark")
                .foregroundColor(Theme.warning)
            Text("Payment issue — please update your payment method")
                .font(.system(size: Theme.fontSizeSM))
                .foregroundColor(Theme.textPrimary)
        }
        .padding(.vertical, Theme.spacingSM)
        .padding(.horizontal, Theme.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.warning.opacity(0.1))
    }
}

struct UsageWarningBanner: View {
    let label: String

    var body: some View {
        HStack {
            Image(systemName: "chart.bar.fill")
                .foregroundColor(Theme.warning)
            Text(label)
                .font(.system(size: Theme.fontSizeSM))
                .foregroundColor(Theme.textPrimary)
        }
        .padding(.vertical, Theme.spacingSM)
        .padding(.horizontal, Theme.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.warning.opacity(0.1))
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
