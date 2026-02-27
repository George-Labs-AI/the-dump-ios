import SwiftUI
import AVFoundation

struct VoiceMemoView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var recorder = AudioRecorderService()
    @StateObject private var player = AudioPlayerService()
    
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var showPermissionAlert = false
    @State private var showDurationWarning = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                VStack(spacing: Theme.spacingLG) {
                    Spacer()
                    
                    // Duration display
                    Text(recorder.formattedDuration)
                        .font(.system(size: 64, weight: .light, design: .monospaced))
                        .foregroundColor(Theme.textPrimary)
                    
                    // Warning for long recordings
                    if recorder.isOverWarningLimit && recorder.state == .recording {
                        Text("Recording is getting long. Consider stopping soon.")
                            .font(.system(size: Theme.fontSizeSM))
                            .foregroundColor(Theme.accent)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Waveform placeholder
                    WaveformView(isRecording: recorder.state == .recording)
                        .frame(height: 60)
                        .padding(.horizontal, Theme.spacingLG)
                    
                    Spacer()
                    
                    // Controls
                    controlsSection
                    
                    // Error display
                    if let error = uploadError ?? recorder.errorMessage {
                        Text(error)
                            .font(.system(size: Theme.fontSizeSM))
                            .foregroundColor(Theme.accent)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Voice Memo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        handleCancel()
                    }
                    .foregroundColor(Theme.textPrimary)
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear {
            checkPermissions()
        }
        .alert("Microphone Access Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {
                dismiss()
            }
        } message: {
            Text("Please enable microphone access in Settings to record voice memos.")
        }
    }
    
    @ViewBuilder
    private var controlsSection: some View {
        switch recorder.state {
        case .idle:
            // Record button
            RecordButton(isRecording: false) {
                startRecording()
            }
            
        case .recording:
            HStack(spacing: Theme.spacingXL) {
                // Pause button
                CircleButton(icon: "pause.fill", size: 56) {
                    recorder.pauseRecording()
                }
                
                // Stop button
                RecordButton(isRecording: true) {
                    recorder.stopRecording()
                }
                
                // Spacer for symmetry
                CircleButton(icon: "xmark", size: 56) {
                    recorder.discardRecording()
                }
                .opacity(0.6)
            }
            
        case .paused:
            HStack(spacing: Theme.spacingXL) {
                // Resume button
                CircleButton(icon: "play.fill", size: 56) {
                    recorder.resumeRecording()
                }
                
                // Stop button
                RecordButton(isRecording: false) {
                    recorder.stopRecording()
                }
                
                // Discard button
                CircleButton(icon: "xmark", size: 56) {
                    recorder.discardRecording()
                }
                .opacity(0.6)
            }
            
        case .stopped:
            // Playback and upload controls
            VStack(spacing: Theme.spacingLG) {
                // Playback controls
                PlaybackControls(player: player)
                
                // Action buttons
                HStack(spacing: Theme.spacingMD) {
                    Button("Discard") {
                        recorder.discardRecording()
                        player.reset()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    Button(action: uploadRecording) {
                        HStack {
                            if isUploading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.textPrimary))
                                    .scaleEffect(0.8)
                            }
                            Text(isUploading ? "Uploading…" : "Upload")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(isEnabled: !isUploading))
                    .disabled(isUploading)
                }
            }
            .onAppear {
                loadPlayback()
            }
        }
    }
    
    // MARK: - Actions
    
    private func checkPermissions() {
        Task {
            if !recorder.hasPermission() {
                let granted = await recorder.requestPermission()
                if !granted {
                    showPermissionAlert = true
                }
            }
        }
    }
    
    private func startRecording() {
        do {
            try recorder.startRecording()
        } catch {
            recorder.errorMessage = error.localizedDescription
        }
    }
    
    private func loadPlayback() {
        guard let url = recorder.currentFileURL else { return }
        do {
            try player.loadAudio(from: url)
        } catch {
            recorder.errorMessage = "Failed to load playback: \(error.localizedDescription)"
        }
    }
    
    private func uploadRecording() {
        guard let fileURL = recorder.currentFileURL else {
            uploadError = "No recording found"
            return
        }
        
        Task {
            guard let email = appState.userEmail,
                  let idToken = await appState.idToken else {
                uploadError = "Not authenticated"
                return
            }
            
            isUploading = true
            uploadError = nil
            
            // Create session item
            let item = SessionItem(
                kind: .audio,
                originalFilename: fileURL.lastPathComponent,
                localFileURL: fileURL,
                status: .uploading
            )
            sessionStore.addItem(item)
            
            do {
                let response = try await UploadService.shared.uploadAudio(
                    fileURL: fileURL,
                    userEmail: email,
                    idToken: idToken
                )
                sessionStore.markSuccess(id: item.id, storagePath: response.storagePath)
                
                // Clean up local file after successful upload
                try? FileManager.default.removeItem(at: fileURL)
                
                dismiss()
            } catch {
                sessionStore.markFailed(id: item.id, error: error.localizedDescription)
                uploadError = error.localizedDescription
            }
            
            isUploading = false
        }
    }
    
    private func handleCancel() {
        if recorder.state == .recording || recorder.state == .paused {
            recorder.discardRecording()
        }
        player.reset()
        dismiss()
    }
}

// MARK: - Subviews

struct RecordButton: View {
    let isRecording: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(Theme.accent, lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                if isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.accent)
                        .frame(width: 28, height: 28)
                } else {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 64, height: 64)
                }
            }
        }
    }
}

struct CircleButton: View {
    let icon: String
    let size: CGFloat
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Theme.surface2)
                    .frame(width: size, height: size)
                
                Image(systemName: icon)
                    .font(.system(size: size * 0.4))
                    .foregroundColor(Theme.textPrimary)
            }
        }
    }
}

struct WaveformView: View {
    let isRecording: Bool
    @State private var animationPhase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 3) {
                ForEach(0..<30, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.accent.opacity(isRecording ? 1 : 0.3))
                        .frame(width: 4)
                        .frame(height: barHeight(for: index, in: geometry.size.height))
                        .animation(
                            isRecording ? .easeInOut(duration: 0.3).repeatForever(autoreverses: true).delay(Double(index) * 0.05) : .default,
                            value: isRecording
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func barHeight(for index: Int, in maxHeight: CGFloat) -> CGFloat {
        if isRecording {
            return CGFloat.random(in: 10...maxHeight)
        } else {
            return 10
        }
    }
}

struct PlaybackControls: View {
    @ObservedObject var player: AudioPlayerService
    
    var body: some View {
        VStack(spacing: Theme.spacingMD) {
            // Progress
            HStack {
                Text(player.formattedCurrentTime)
                    .font(.system(size: Theme.fontSizeXS, design: .monospaced))
                    .foregroundColor(Theme.textSecondary)
                
                Spacer()
                
                Text(player.formattedDuration)
                    .font(.system(size: Theme.fontSizeXS, design: .monospaced))
                    .foregroundColor(Theme.textSecondary)
            }
            
            // Slider
            Slider(
                value: Binding(
                    get: { player.currentTime },
                    set: { player.seek(to: $0) }
                ),
                in: 0...max(player.duration, 0.01)
            )
            .tint(Theme.accent)
            
            // Play/Pause
            Button(action: {
                if player.isPlaying {
                    player.pause()
                } else {
                    player.play()
                }
            }, label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(Theme.accent)
            })
        }
        .padding(.horizontal, Theme.spacingLG)
    }
}

#Preview {
    VoiceMemoView()
        .environmentObject(AppState())
        .environmentObject(SessionStore())
}
