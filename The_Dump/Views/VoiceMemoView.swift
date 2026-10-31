import SwiftUI
import AVFoundation

/// Recording a voice note (Paper, 05 Voice). It starts recording as soon as
/// it opens: a large timer, a grey waveform of the microphone's level, an
/// outlined pause and stop, and Discard as grey text. After stopping it says
/// "Ready to dump." with one Upload button. Shown full screen, so a stray
/// swipe can't throw a recording away.
struct VoiceMemoView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var recorder = AudioRecorderService()

    @State private var isUploading = false
    @State private var uploadProgress: Double?
    @State private var uploadError: String?
    @State private var showPermissionAlert = false
    @State private var showDiscardConfirmation = false
    @State private var micUnavailable = false
    /// The last few level readings, newest last, drawn as the waveform.
    @State private var levels: [Float] = Array(repeating: 0, count: VoiceWaveform.barCount)

    var body: some View {
        VStack(spacing: 0) {
            Text("Voice")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: Theme.spacingXL) {
                Spacer(minLength: 0)

                VStack(spacing: Theme.spacingSM) {
                    Text(Self.timerText(recorder.duration))
                        .font(.display(52))
                        .tracking(52 * -0.04)
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                        .accessibilityLabel("Length")
                        .accessibilityValue(Self.timerText(recorder.duration))
                    Text(caption)
                        .tdCaption()
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VoiceWaveform(levels: levels)

                controls

                if let error = uploadError ?? recorder.errorMessage {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.screenH)
            .padding(.bottom, Theme.spacingLG)
        }
        .background(Theme.background.ignoresSafeArea())
        .task {
            await startWhenAllowed()
        }
        .onChange(of: recorder.level) { _, newLevel in
            guard recorder.state == .recording else { return }
            levels.removeFirst()
            levels.append(newLevel)
        }
        .alert("Microphone Access Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable microphone access in Settings to record voice memos.")
        }
        .alert("Discard this recording?", isPresented: $showDiscardConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Discard", role: .destructive) {
                discardAndClose()
            }
        } message: {
            Text("It won't be saved.")
        }
    }

    private var caption: String {
        if micUnavailable { return "The microphone is off for The Dump." }
        switch recorder.state {
        case .idle:
            return "Starting…"
        case .recording:
            return recorder.isOverWarningLimit
                ? "Recording is getting long. Consider stopping soon."
                : "Recording"
        case .paused:
            return "Paused"
        case .stopped:
            return isUploading ? "Uploading…" : "Ready to dump."
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private var controls: some View {
        switch recorder.state {
        case .recording, .paused:
            VStack(spacing: Theme.spacingXL) {
                // The empty 56pt slot on the right keeps stop centred.
                HStack(spacing: Theme.spacingLG) {
                    if recorder.state == .recording {
                        OutlinedCircleButton(systemImage: "pause.fill", size: 56, iconSize: 18, label: "Pause") {
                            recorder.pauseRecording()
                        }
                    } else {
                        OutlinedCircleButton(systemImage: "play.fill", size: 56, iconSize: 18, label: "Resume") {
                            recorder.resumeRecording()
                        }
                    }
                    OutlinedCircleButton(systemImage: "stop.fill", size: 72, iconSize: 22, label: "Stop") {
                        recorder.stopRecording()
                    }
                    Color.clear
                        .frame(width: 56, height: 56)
                        .accessibilityHidden(true)
                }
                discardButton
            }

        case .stopped:
            VStack(spacing: Theme.spacingMD) {
                if let uploadProgress {
                    TDMeter(value: uploadProgress)
                }
                Button(isUploading ? "Uploading…" : "Upload") {
                    uploadRecording()
                }
                .buttonStyle(TDPrimaryButtonStyle())
                .disabled(isUploading)
                discardButton
                    .disabled(isUploading)
            }

        case .idle:
            Button("Close") {
                dismiss()
            }
            .buttonStyle(TDTextLinkStyle(size: 17))
            .fontWeight(.medium)
        }
    }

    private var discardButton: some View {
        Button("Discard") {
            if recorder.duration > 0 {
                showDiscardConfirmation = true
            } else {
                discardAndClose()
            }
        }
        .buttonStyle(TDTextLinkStyle(size: 17))
        .fontWeight(.medium)
        .padding(.horizontal, Theme.spacingSMPlus)
    }

    // MARK: - Actions

    /// Start recording straight away; ask for the microphone first if needed.
    private func startWhenAllowed() async {
        guard recorder.state == .idle else { return }
        if !recorder.hasPermission() {
            guard await recorder.requestPermission() else {
                micUnavailable = true
                showPermissionAlert = true
                return
            }
        }
        do {
            try recorder.startRecording()
        } catch {
            recorder.errorMessage = error.localizedDescription
        }
    }

    private func discardAndClose() {
        if recorder.state != .idle {
            recorder.discardRecording()
        }
        dismiss()
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
            uploadProgress = 0

            // Create session item
            let item = SessionItem(
                kind: .audio,
                originalFilename: fileURL.lastPathComponent,
                localFileURL: fileURL,
                status: .uploading
            )
            sessionStore.addItem(item)

            do {
                _ = try await UploadService.shared.uploadAudio(
                    fileURL: fileURL,
                    userEmail: email,
                    idToken: idToken,
                    onProgress: { progress in
                        Task { @MainActor in
                            uploadProgress = progress
                            sessionStore.updateProgress(id: item.id, progress: progress)
                        }
                    }
                )
                // The PendingNoteRecord is added before uploadAudio returns —
                // the Processing row on the capture screen takes over, so
                // drop the transient session row instead of overlapping it
                // with "Captured!".
                sessionStore.removeItem(id: item.id)

                // Clean up local file after successful upload
                try? FileManager.default.removeItem(at: fileURL)

                dismiss()
            } catch {
                sessionStore.markFailed(id: item.id, error: error.localizedDescription)
                uploadError = error.localizedDescription
                uploadProgress = nil
            }

            isUploading = false
        }
    }

    /// "1:12": minutes without a leading zero, as on Paper.
    static func timerText(_ duration: TimeInterval) -> String {
        let total = max(0, Int(duration))
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }
}

/// An outlined white circle with a filled white symbol: pause, resume and
/// stop. No red and no pulsing (Paper, 05 Voice).
private struct OutlinedCircleButton: View {
    let systemImage: String
    let size: CGFloat
    let iconSize: CGFloat
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: .regular))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: size, height: size)
                .overlay(Circle().strokeBorder(Theme.textPrimary, lineWidth: 1.5))
                .contentShape(Circle())
        }
        .buttonStyle(TDPressStyle(pressedOpacity: 0.7))
        .accessibilityLabel(label)
    }
}

/// The microphone's recent levels as grey bars, 3pt wide with 4pt between,
/// up to 48pt tall. It holds still when recording pauses or stops.
struct VoiceWaveform: View {
    static let barCount = 36
    let levels: [Float]

    var body: some View {
        HStack(alignment: .center, spacing: Theme.spacingXS) {
            ForEach(levels.indices, id: \.self) { index in
                Capsule()
                    .fill(Theme.textSecondary)
                    .frame(width: 3, height: 4 + CGFloat(max(0, min(1, levels[index]))) * 44)
            }
        }
        .frame(height: 48)
        .animation(.linear(duration: 0.1), value: levels)
        .accessibilityHidden(true)
    }
}
