import SwiftUI

// MARK: - Screen 3: follow-up questions (and 3c)

struct OnboardingQuestionsScreen: View {
    @ObservedObject var viewModel: OnboardingV2ViewModel
    @StateObject private var recorder = AudioRecorderService()
    @State private var micDenied = false
    @State private var isBuilding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingProgressBar(filled: 2)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(viewModel.questionsHeadline)
                        .onboardingHeadline()
                        .accessibilityAddTraits(.isHeader)
                    Text(viewModel.questionsBody)
                        .onboardingBody()
                    if micDenied {
                        micDeniedNotice
                    }
                    VStack(spacing: 12) {
                        ForEach(viewModel.progress.followups.indices, id: \.self) { index in
                            OnboardingQuestionCard(
                                viewModel: viewModel,
                                recorder: recorder,
                                index: index,
                                onMicDenied: { micDenied = true }
                            )
                        }
                    }
                    .padding(.top, 16)
                }
                .padding(.horizontal, OnboardingStyle.gutter)
                .padding(.top, 40)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            Button {
                isBuilding = true
                if recorder.state == .recording {
                    recorder.discardRecording()
                }
                Task { await viewModel.buildCategories() }
            } label: {
                HStack(spacing: 8) {
                    if isBuilding && viewModel.isWaitingForAnswers {
                        ProgressView().tint(OnboardingStyle.background)
                    }
                    Text("Build my categories")
                }
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())
            .disabled(isBuilding)
            .padding(.horizontal, OnboardingStyle.gutter)
            .padding(.bottom, 48)
        }
    }

    /// The same notice as 2e, for an answer tapped without mic access.
    private var micDeniedNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            OnboardingNoMicCard()
            Button("Open Settings") { OnboardingMicrophone.openSettings() }
                .buttonStyle(OnboardingLinkStyle())
                .frame(maxWidth: .infinity)
        }
    }
}

/// One question: answered or being turned into text (grey card), waiting
/// for an answer (outlined, with Answer / Type / Skip), or being typed or
/// recorded (3c).
struct OnboardingQuestionCard: View {
    @ObservedObject var viewModel: OnboardingV2ViewModel
    @ObservedObject var recorder: AudioRecorderService
    let index: Int
    let onMicDenied: () -> Void
    @State private var typed = ""
    @FocusState private var isFocused: Bool

    private var followup: OnboardingFollowup { viewModel.progress.followups[index] }
    private var state: OnboardingV2ViewModel.AnswerState? { viewModel.answerStates[index] }

    /// Outlined while it is waiting for this person; grey once it has an
    /// answer (or one is on its way).
    private var isOutlined: Bool {
        switch state {
        case .recording, .typing, .transcribeFailed:
            return true
        case .transcribing:
            return false
        case nil:
            return viewModel.activeQuestionIndex == index
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isOutlined ? 16 : 12) {
            Text(followup.question)
                .font(OnboardingStyle.bodyMedium)
                .foregroundColor(followup.isAnswered && state == nil ? OnboardingStyle.secondary : OnboardingStyle.text)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            content
        }
        .padding(OnboardingStyle.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: OnboardingStyle.cardRadius)
                .fill(isOutlined ? Color.clear : OnboardingStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OnboardingStyle.cardRadius)
                .strokeBorder(isOutlined ? OnboardingStyle.placeholder : Color.clear, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .recording:
            recordingRow
        case .transcribing:
            HStack(spacing: 8) {
                ProgressView()
                    .tint(OnboardingStyle.text)
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
                Text("Listening back to your answer…").onboardingCaption()
            }
        case .typing:
            typingRow
        case .transcribeFailed:
            VStack(alignment: .leading, spacing: 12) {
                Text("That didn’t come through. Type it instead?").onboardingCaption()
                HStack {
                    Button("Type it instead") { viewModel.startTypingAnswer(index) }
                        .buttonStyle(OnboardingLinkStyle(color: OnboardingStyle.text))
                    Spacer()
                    Button("Skip") { viewModel.skipQuestion(index) }
                        .buttonStyle(OnboardingLinkStyle())
                }
            }
        case nil:
            settledRow
        }
    }

    @ViewBuilder
    private var settledRow: some View {
        if followup.isAnswered, let answer = followup.answer {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(OnboardingStyle.text)
                    .frame(width: 16, height: 16)
                    .padding(.top, 3)
                Text("“\(answer)”")
                    .onboardingBody(OnboardingStyle.text)
            }
        } else if followup.source == .skipped {
            HStack {
                Text("Skipped").onboardingCaption()
                Spacer()
                Button("Answer") { viewModel.startTypingAnswer(index) }
                    .buttonStyle(OnboardingLinkStyle(color: OnboardingStyle.text))
            }
        } else if viewModel.activeQuestionIndex == index {
            actionRow
        }
    }

    private var actionRow: some View {
        HStack {
            Button {
                startRecording()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "mic")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(OnboardingStyle.background)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(OnboardingStyle.text))
                    Text("Answer")
                        .font(OnboardingStyle.bodyMedium)
                        .foregroundColor(OnboardingStyle.text)
                }
            }
            .buttonStyle(.plain)
            .disabled(recorder.state == .recording)
            Spacer()
            HStack(spacing: 20) {
                Button("Type") { viewModel.startTypingAnswer(index) }
                    .buttonStyle(OnboardingLinkStyle(color: OnboardingStyle.text))
                Button("Skip") { viewModel.skipQuestion(index) }
                    .buttonStyle(OnboardingLinkStyle())
            }
        }
    }

    private var recordingRow: some View {
        HStack(spacing: 12) {
            Button {
                stopRecording()
            } label: {
                RoundedRectangle(cornerRadius: 3)
                    .fill(OnboardingStyle.text)
                    .frame(width: 12, height: 12)
                    .frame(width: 40, height: 40)
                    .overlay(Circle().strokeBorder(OnboardingStyle.text, lineWidth: 2))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop recording")
            Text(OnboardingRecordingPrompt.clock(recorder.duration))
                .font(OnboardingStyle.bodyMedium)
                .monospacedDigit()
                .foregroundColor(OnboardingStyle.text)
            OnboardingLevelBars(level: recorder.level, barCount: 8)
            Spacer()
            Button("Cancel") {
                recorder.discardRecording()
                viewModel.cancelAnswerInput(index)
            }
            .buttonStyle(OnboardingLinkStyle())
        }
    }

    private var typingRow: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("", text: $typed, axis: .vertical)
                .font(OnboardingStyle.body)
                .foregroundColor(OnboardingStyle.text)
                .lineSpacing(4)
                .lineLimit(1...6)
                .focused($isFocused)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(RoundedRectangle(cornerRadius: 10).fill(OnboardingStyle.surface))
                .onAppear { isFocused = true }
                .accessibilityLabel("Your answer")
            HStack {
                Button {
                    viewModel.submitTypedAnswer(index, text: typed)
                } label: {
                    Text("Done")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(OnboardingStyle.background)
                        .padding(.horizontal, 18)
                        .frame(height: 36)
                        .background(Capsule().fill(OnboardingStyle.text))
                }
                .buttonStyle(.plain)
                .disabled(typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
                HStack(spacing: 20) {
                    Button("Talk instead") {
                        viewModel.cancelAnswerInput(index)
                        startRecording()
                    }
                    .buttonStyle(OnboardingLinkStyle(color: OnboardingStyle.text))
                    Button("Skip") { viewModel.skipQuestion(index) }
                        .buttonStyle(OnboardingLinkStyle())
                }
            }
        }
    }

    private func startRecording() {
        Task {
            guard await OnboardingMicrophone.isAllowed() else {
                onMicDenied()
                viewModel.startTypingAnswer(index)
                return
            }
            do {
                try recorder.startRecording(sampleRate: 16_000)
                viewModel.startAnswerRecording(index)
            } catch {
                recorder.reset()
                viewModel.startTypingAnswer(index)
            }
        }
    }

    private func stopRecording() {
        guard let file = recorder.currentFileURL else { return }
        recorder.stopRecording()
        recorder.reset()
        viewModel.submitAnswerRecording(index, fileURL: file)
    }
}
