import SwiftUI
import AVFoundation
import Combine

// MARK: - Microphone permission

/// Asks for the microphone when needed. `false` means it was refused, now
/// or before (screen 2e).
@MainActor
enum OnboardingMicrophone {
    static func isAllowed() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        default:
            return await AVAudioApplication.requestRecordPermission()
        }
    }

    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Screen 2: what are you juggling (and 2c, 2d, 2e)

struct OnboardingRecordScreen: View {
    @ObservedObject var viewModel: OnboardingV2ViewModel
    @StateObject private var recorder = AudioRecorderService()
    @State private var typedText = ""
    @State private var exampleIndex = 0
    @State private var recordError: String?
    @FocusState private var isTyping: Bool

    /// "Try saying" turns every 4 seconds and stops while recording.
    private let rotation = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingProgressBar(filled: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("What are you juggling?")
                        .onboardingHeadline()
                        .accessibilityAddTraits(.isHeader)
                    Text("Your categories come from this. Tell us about the different things on your plate, what you save, and the kinds of notes you take. The more you cover, the better they’ll fit.")
                        .onboardingBody()
                    middle
                        .padding(.top, 16)
                }
                .padding(.horizontal, OnboardingStyle.gutter)
                .padding(.top, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            bottom
                .padding(.horizontal, OnboardingStyle.gutter)
                .padding(.bottom, viewModel.recordMode == .idle ? 48 : 40)
        }
        .onReceive(rotation) { _ in
            guard viewModel.recordMode == .idle, viewModel.trySaying.count > 1 else { return }
            withAnimation { exampleIndex = (exampleIndex + 1) % viewModel.trySaying.count }
        }
        .onChange(of: recorder.duration) { _, duration in
            if recorder.state == .recording, duration >= viewModel.recordingLimits.hardStopSeconds {
                stopAndSend()
            }
        }
        .onDisappear {
            if recorder.state == .recording {
                recorder.discardRecording()
            }
        }
    }

    // MARK: Middle of the screen

    @ViewBuilder
    private var middle: some View {
        switch viewModel.recordMode {
        case .idle, .recording:
            if !viewModel.trySaying.isEmpty {
                trySayingCard
            }
        case .typing:
            typingBox
        case .micDenied:
            OnboardingNoMicCard()
        }
    }

    private var trySayingCard: some View {
        let examples = viewModel.trySaying
        let index = min(exampleIndex, examples.count - 1)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Try saying").onboardingLabel()
                Spacer()
                HStack(spacing: 4) {
                    ForEach(examples.indices, id: \.self) { dot in
                        Circle()
                            .fill(dot == index ? OnboardingStyle.text : OnboardingStyle.hairline)
                            .frame(width: 5, height: 5)
                    }
                }
                .accessibilityHidden(true)
            }
            Text("“\(examples[index])”")
                .onboardingBody(OnboardingStyle.text)
                .id(index)
                .transition(.opacity)
        }
        .onboardingCard()
    }

    private var typingBox: some View {
        ZStack(alignment: .topLeading) {
            if typedText.isEmpty {
                Text("I run a small design studio with two clients, we’re redoing the kitchen…")
                    .onboardingBody(OnboardingStyle.placeholder)
                    .padding(20)
                    .accessibilityHidden(true)
            }
            TextEditor(text: $typedText)
                .font(OnboardingStyle.body)
                .foregroundColor(OnboardingStyle.text)
                .lineSpacing(6)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
                .focused($isTyping)
                .accessibilityLabel("What you're juggling")
        }
        .frame(height: 240)
        .background(
            RoundedRectangle(cornerRadius: OnboardingStyle.cardRadius)
                .fill(OnboardingStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OnboardingStyle.cardRadius)
                .stroke(OnboardingStyle.placeholder, lineWidth: 1)
        )
    }

    // MARK: Bottom of the screen

    @ViewBuilder
    private var bottom: some View {
        switch viewModel.recordMode {
        case .idle:
            VStack(spacing: 24) {
                OnboardingMicButton { startRecording() }
                VStack(spacing: 8) {
                    Text("Tap and talk. The more, the better.")
                        .font(OnboardingStyle.bodyMedium)
                        .foregroundColor(OnboardingStyle.text)
                    if let notice = recordError ?? viewModel.recordNotice {
                        Text(notice)
                            .onboardingCaption()
                            .multilineTextAlignment(.center)
                    }
                    Button("Type instead") { viewModel.startTyping() }
                        .buttonStyle(OnboardingLinkStyle())
                }
            }
            .frame(maxWidth: .infinity)
        case .recording:
            recordingControls
        case .typing:
            VStack(spacing: 16) {
                typingHint
                Button("Continue") {
                    let text = typedText
                    isTyping = false
                    Task { await viewModel.submitTyped(text) }
                }
                .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: !typedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                .disabled(typedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Talk instead") {
                    isTyping = false
                    viewModel.talkInstead()
                }
                .buttonStyle(OnboardingLinkStyle())
            }
        case .micDenied:
            VStack(spacing: 16) {
                Button("Type instead") { viewModel.startTyping() }
                    .buttonStyle(OnboardingPrimaryButtonStyle())
                Button("Open Settings") { OnboardingMicrophone.openSettings() }
                    .buttonStyle(OnboardingLinkStyle())
            }
        }
    }

    /// Under about 20 words the hint asks for a little more; it never
    /// blocks Continue.
    private var typingHint: some View {
        let words = OnboardingV2ViewModel.wordCount(typedText)
        return HStack(alignment: .firstTextBaseline) {
            Text(words > 0 && words < 20 ? "A sentence or two more helps." : "Work, home, ideas: all of it helps.")
                .onboardingCaption()
            Spacer()
            Text(words == 1 ? "1 word" : "\(words) words")
                .onboardingCaption()
                .monospacedDigit()
        }
    }

    private var recordingControls: some View {
        let limits = viewModel.recordingLimits
        let prompt = recorder.duration >= limits.warnAtSeconds
            ? "1 minute left"
            : OnboardingRecordingPrompt.text(for: recorder.duration)
        return VStack(spacing: 16) {
            Text(prompt)
                .onboardingCaption()
                .animation(.easeInOut, value: prompt)
            Text(OnboardingRecordingPrompt.clock(recorder.duration))
                .font(OnboardingStyle.display(52))
                .tracking(52 * -0.03)
                .monospacedDigit()
                .foregroundColor(OnboardingStyle.text)
                .accessibilityLabel("Recording, \(OnboardingRecordingPrompt.clock(recorder.duration))")
            OnboardingLevelBars(level: recorder.level, isRecording: recorder.state == .recording)
            Button(action: stopAndSend) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(OnboardingStyle.text)
                    .frame(width: 26, height: 26)
                    .frame(width: 88, height: 88)
                    .overlay(Circle().stroke(OnboardingStyle.text, lineWidth: 2))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop recording")
            VStack(spacing: 8) {
                Text("Tap to stop")
                    .font(OnboardingStyle.bodyMedium)
                    .foregroundColor(OnboardingStyle.text)
                HStack(spacing: 4) {
                    Text("Up to 10 minutes ·").onboardingCaption()
                    Button("Start over") {
                        recorder.discardRecording()
                        viewModel.recordingDiscarded()
                    }
                    .buttonStyle(OnboardingLinkStyle())
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Actions

    private func startRecording() {
        recordError = nil
        Task {
            guard await OnboardingMicrophone.isAllowed() else {
                viewModel.showMicDenied()
                return
            }
            do {
                try recorder.startRecording(sampleRate: 16_000)
                viewModel.recordingStarted()
            } catch {
                recorder.reset()
                recordError = "Couldn’t start recording. Try again, or type instead."
            }
        }
    }

    private func stopAndSend() {
        guard recorder.state == .recording, let file = recorder.currentFileURL else { return }
        recorder.stopRecording()
        recorder.reset()
        Task { await viewModel.submitRecording(fileURL: file) }
    }
}

// MARK: - Recording pieces

/// The grey line above the timer on 2c: encouragement that changes every
/// 30 seconds or so. There is no "that's plenty" nudge (D-021).
enum OnboardingRecordingPrompt {
    static let prompts = [
        "Keep going. The more you say, the better.",
        "Anything at home?",
        "Any ideas you keep losing?",
        "Keep going. The more you say, the better.",
        "Anyone you’re juggling things for?",
        "Anything you’re saving to read or try?"
    ]

    static func text(for elapsed: TimeInterval) -> String {
        prompts[Int(elapsed / 30) % prompts.count]
    }

    /// "2:04".
    static func clock(_ elapsed: TimeInterval) -> String {
        let seconds = Int(elapsed)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// A row of level bars: the most recent levels, newest on the right, with
/// short dim bars until enough have been heard.
struct OnboardingLevelBars: View {
    /// The two drawn sizes: white on black (2c, 3) and black on the white
    /// capture bar (5b).
    struct Style {
        var color: Color = OnboardingStyle.text
        var waitingColor: Color = OnboardingStyle.text.opacity(0.3)
        var barWidth: CGFloat = 3
        var spacing: CGFloat = 5
        var maxHeight: CGFloat = 28
        var minHeight: CGFloat = 6

        static let standard = Style()
        static let captureBar = Style(
            color: OnboardingStyle.background,
            waitingColor: OnboardingStyle.secondary,
            barWidth: 2,
            spacing: 4,
            maxHeight: 18,
            minHeight: 4
        )
    }

    let level: Float
    var isRecording = true
    var barCount = 14
    var style: Style = .standard
    @State private var history: [Float] = []

    var body: some View {
        HStack(alignment: .center, spacing: style.spacing) {
            ForEach(0..<barCount, id: \.self) { index in
                let sample = index < history.count ? history[index] : nil
                Capsule()
                    .fill(sample == nil ? style.waitingColor : style.color)
                    .frame(width: style.barWidth, height: sample.map { max(style.minHeight, style.maxHeight * CGFloat($0)) } ?? style.minHeight)
            }
        }
        .frame(height: style.maxHeight)
        .animation(.easeOut(duration: 0.1), value: history)
        .onChange(of: level) { _, newLevel in
            guard isRecording else { return }
            history.append(newLevel)
            if history.count > barCount {
                history.removeFirst(history.count - barCount)
            }
        }
        .accessibilityHidden(true)
    }
}
