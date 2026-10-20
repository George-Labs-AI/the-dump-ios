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
            .padding(.bottom, 40)
        }
    }

    /// The same notice as 2e, for an answer tapped without mic access.
    private var micDeniedNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No mic? Type instead.")
                .font(OnboardingStyle.bodyMedium)
                .foregroundColor(OnboardingStyle.text)
            Text("The Dump can’t use your microphone. Typing works just as well, or turn the mic on in Settings and come back.")
                .onboardingCaption()
            Button("Open Settings") { OnboardingMicrophone.openSettings() }
                .buttonStyle(OnboardingLinkStyle(color: OnboardingStyle.text))
        }
        .onboardingCard(padding: 16)
    }
}

/// One question: answered (grey, with a check and the answer), active
/// (outlined, with Answer / Type / Skip), or one of 3c's in-between states.
struct OnboardingQuestionCard: View {
    @ObservedObject var viewModel: OnboardingV2ViewModel
    @ObservedObject var recorder: AudioRecorderService
    let index: Int
    let onMicDenied: () -> Void
    @State private var typed = ""
    @FocusState private var isFocused: Bool

    private var followup: OnboardingFollowup { viewModel.progress.followups[index] }
    private var state: OnboardingV2ViewModel.AnswerState? { viewModel.answerStates[index] }
    private var isActive: Bool { viewModel.activeQuestionIndex == index || state != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(followup.question)
                .font(OnboardingStyle.bodyMedium)
                .foregroundColor(OnboardingStyle.text)
                .fixedSize(horizontal: false, vertical: true)
            content
        }
        .padding(OnboardingStyle.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: OnboardingStyle.cardRadius)
                .fill(isActive ? OnboardingStyle.background : OnboardingStyle.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OnboardingStyle.cardRadius)
                .stroke(isActive ? OnboardingStyle.text : Color.clear, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .recording:
            recordingRow
        case .transcribing:
            HStack(spacing: 10) {
                ProgressView().tint(OnboardingStyle.secondary)
                Text("Listening back to your answer…").onboardingCaption()
            }
        case .typing:
            typingRow
        case .transcribeFailed:
            VStack(alignment: .leading, spacing: 10) {
                Text("That didn’t come through.").onboardingCaption()
                HStack(spacing: 16) {
                    Button("Type it instead") { viewModel.startTypingAnswer(index) }
                        .buttonStyle(OnboardingLinkStyle(color: OnboardingStyle.text))
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
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(OnboardingStyle.text)
                    .padding(.top, 2)
                Text("“\(answer)”").onboardingCaption()
            }
        } else if followup.source == .skipped {
            HStack {
                Text("Skipped").onboardingCaption()
                Spacer()
                Button("Answer") { viewModel.cancelAnswerInput(index); unskip() }
                    .buttonStyle(OnboardingLinkStyle(color: OnboardingStyle.text))
            }
        } else if viewModel.activeQuestionIndex == index {
            actionRow
        }
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                startRecording()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "mic")
                        .font(.system(size: 15, weight: .medium))
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
            Button("Type") { viewModel.startTypingAnswer(index) }
                .buttonStyle(OnboardingLinkStyle(color: OnboardingStyle.text, font: OnboardingStyle.body))
            Button("Skip") { viewModel.skipQuestion(index) }
                .buttonStyle(OnboardingLinkStyle(font: OnboardingStyle.body))
                .padding(.leading, 8)
        }
    }

    private var recordingRow: some View {
        HStack(spacing: 12) {
            Button {
                stopRecording()
            } label: {
                RoundedRectangle(cornerRadius: 3)
                    .fill(OnboardingStyle.background)
                    .frame(width: 12, height: 12)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(OnboardingStyle.text))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop recording")
            Text(OnboardingRecordingPrompt.clock(recorder.duration))
                .font(OnboardingStyle.bodyMedium)
                .monospacedDigit()
                .foregroundColor(OnboardingStyle.text)
            OnboardingLevelBars(level: recorder.level)
                .scaleEffect(0.7, anchor: .leading)
            Spacer()
            Button("Cancel") {
                recorder.discardRecording()
                viewModel.cancelAnswerInput(index)
            }
            .buttonStyle(OnboardingLinkStyle())
        }
    }

    private var typingRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("", text: $typed, axis: .vertical)
                .font(OnboardingStyle.body)
                .foregroundColor(OnboardingStyle.text)
                .lineLimit(2...6)
                .focused($isFocused)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(OnboardingStyle.surface))
                .onAppear { isFocused = true }
                .accessibilityLabel("Your answer")
            HStack(spacing: 16) {
                Button("Done") {
                    viewModel.submitTypedAnswer(index, text: typed)
                }
                .font(OnboardingStyle.bodyMedium)
                .foregroundColor(OnboardingStyle.background)
                .padding(.horizontal, 18)
                .frame(height: 36)
                .background(Capsule().fill(OnboardingStyle.text))
                .disabled(typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
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

    private func unskip() {
        viewModel.startTypingAnswer(index)
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
