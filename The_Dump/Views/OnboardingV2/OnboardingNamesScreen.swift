import SwiftUI

// MARK: - Screen 2h: what do these names mean (2g when fewer than two were heard)

/// Right after the ramble: the keywords only this person would know. 2h
/// lists the names heard, each with the AI's guess filled in, plus a row
/// for nicknames that were never said. 2g is an open box for typing or
/// talking. Everything here is optional and goes to drafting as one answer.
struct OnboardingNamesScreen: View {
    @ObservedObject var viewModel: OnboardingV2ViewModel
    @StateObject private var recorder = AudioRecorderService()
    @State private var micDenied = false
    @State private var isContinuing = false
    @FocusState private var focusedRow: Field?

    enum Field: Hashable {
        case name(UUID)
        case meaning(UUID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingProgressBar(filled: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(viewModel.listsNames ? "What do these names mean?" : "Any names only you’d know?")
                        .onboardingHeadline()
                        .accessibilityAddTraits(.isHeader)
                    Text(viewModel.listsNames
                         ? "We heard these in what you said. Say what each one means, and add any nicknames we missed, like what you call a place."
                         : "Nicknames, people, places, project names. Tell us what each one means, so notes that mention it land in the right place.")
                        .onboardingBody()
                    if micDenied {
                        OnboardingNoMicCard()
                    }
                    Group {
                        if viewModel.listsNames {
                            namesList
                        } else {
                            noteBox
                        }
                    }
                    .padding(.top, 16)
                }
                .padding(.horizontal, OnboardingStyle.gutter)
                .padding(.top, 40)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            bottom
                .padding(.horizontal, OnboardingStyle.gutter)
                .padding(.bottom, 40)
        }
        .onDisappear {
            if recorder.state == .recording {
                recorder.discardRecording()
            }
        }
    }

    // MARK: 2h: the names heard

    private var namesList: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.nameRows) { row in
                nameRow(row)
                Rectangle()
                    .fill(OnboardingStyle.hairline)
                    .frame(height: 1)
            }
            Button {
                let id = viewModel.addNameRow()
                focusedRow = .name(id)
            } label: {
                HStack(spacing: 12) {
                    Text("+")
                        .font(.system(size: 18))
                        .frame(width: 12)
                    Text("Add a nickname or name we missed")
                        .font(OnboardingStyle.body)
                    Spacer()
                }
                .foregroundColor(OnboardingStyle.secondary)
                .padding(.horizontal, OnboardingStyle.cardPadding)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(
            RoundedRectangle(cornerRadius: OnboardingStyle.cardRadius)
                .fill(OnboardingStyle.surface)
        )
    }

    private func nameRow(_ row: OnboardingNameRow) -> some View {
        let meaningFocused = focusedRow == .meaning(row.id)
        return VStack(alignment: .leading, spacing: meaningFocused ? 10 : 4) {
            if row.isAdded {
                TextField(
                    "",
                    text: Binding(get: { row.name }, set: { viewModel.updateNameRow(row.id, name: $0) }),
                    prompt: Text("Name or nickname").foregroundColor(OnboardingStyle.placeholder)
                )
                .font(OnboardingStyle.bodyMedium)
                .foregroundColor(OnboardingStyle.text)
                .focused($focusedRow, equals: .name(row.id))
                .submitLabel(.next)
                .onSubmit { focusedRow = .meaning(row.id) }
                .accessibilityLabel("Name or nickname")
            } else {
                Text(row.name)
                    .font(OnboardingStyle.bodyMedium)
                    .foregroundColor(OnboardingStyle.text)
            }
            TextField(
                "",
                text: Binding(get: { row.meaning }, set: { viewModel.updateNameRow(row.id, meaning: $0) }),
                prompt: Text("Who or what is this?").foregroundColor(OnboardingStyle.placeholder),
                axis: .vertical
            )
            .font(.system(size: 15))
            .foregroundColor(meaningFocused ? OnboardingStyle.text : OnboardingStyle.secondary)
            .lineLimit(1...3)
            .focused($focusedRow, equals: .meaning(row.id))
            .submitLabel(.done)
            .padding(.horizontal, meaningFocused ? 14 : 0)
            .padding(.vertical, meaningFocused ? 12 : 0)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(meaningFocused ? OnboardingStyle.background : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(meaningFocused ? OnboardingStyle.text : Color.clear, lineWidth: 1)
            )
            .accessibilityLabel("What \(row.name.isEmpty ? "this name" : row.name) means")
        }
        .padding(.horizontal, OnboardingStyle.cardPadding)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { focusedRow = .meaning(row.id) }
    }

    // MARK: 2g: the open box

    @ViewBuilder
    private var noteBox: some View {
        switch viewModel.namesNoteState {
        case .recording:
            recordingRow
                .onboardingCard()
        case .transcribing:
            HStack(spacing: 8) {
                ProgressView()
                    .tint(OnboardingStyle.text)
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
                Text("Listening back…").onboardingCaption()
            }
            .onboardingCard()
        default:
            VStack(alignment: .leading, spacing: 8) {
                textBox
                if viewModel.namesNoteState == .transcribeFailed {
                    Text("That didn’t come through. Type it instead?").onboardingCaption()
                }
            }
        }
    }

    private var textBox: some View {
        ZStack(alignment: .topLeading) {
            if viewModel.namesNote.isEmpty {
                Text("Landing Lane is the cape house.\nPriya and Acme are client work.")
                    .onboardingBody(OnboardingStyle.placeholder)
                    .padding(20)
                    .accessibilityHidden(true)
            }
            TextEditor(text: Binding(get: { viewModel.namesNote }, set: { viewModel.updateNamesNote($0) }))
                .font(OnboardingStyle.body)
                .foregroundColor(OnboardingStyle.text)
                .lineSpacing(6)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 15)
                .padding(.vertical, 12)
                .accessibilityLabel("Names only you'd know")
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

    private var recordingRow: some View {
        HStack(spacing: 12) {
            Button(action: stopRecording) {
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
                viewModel.cancelNamesRecording()
            }
            .buttonStyle(OnboardingLinkStyle())
        }
    }

    // MARK: Bottom

    private var bottom: some View {
        VStack(spacing: 16) {
            if !viewModel.listsNames {
                Text("Say what each one means.")
                    .onboardingCaption()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                focusedRow = nil
                isContinuing = true
                if recorder.state == .recording {
                    recorder.discardRecording()
                }
                Task { await viewModel.continueFromNames() }
            } label: {
                HStack(spacing: 8) {
                    if isContinuing && viewModel.isWaitingForNamesNote {
                        ProgressView().tint(OnboardingStyle.background)
                    }
                    Text("Continue")
                }
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())
            .disabled(isContinuing)
            if !viewModel.listsNames {
                HStack(spacing: 28) {
                    if viewModel.namesNoteState != .recording && viewModel.namesNoteState != .transcribing {
                        Button("Talk instead", action: startRecording)
                            .buttonStyle(OnboardingLinkStyle())
                    }
                    Button("Skip") {
                        isContinuing = true
                        if recorder.state == .recording {
                            recorder.discardRecording()
                        }
                        Task { await viewModel.skipNames() }
                    }
                    .buttonStyle(OnboardingLinkStyle())
                    .disabled(isContinuing)
                }
            }
        }
    }

    // MARK: Actions

    private func startRecording() {
        Task {
            guard await OnboardingMicrophone.isAllowed() else {
                micDenied = true
                viewModel.startTypingNames()
                return
            }
            do {
                try recorder.startRecording(sampleRate: 16_000)
                viewModel.startNamesRecording()
            } catch {
                recorder.reset()
                viewModel.startTypingNames()
            }
        }
    }

    private func stopRecording() {
        guard let file = recorder.currentFileURL else { return }
        recorder.stopRecording()
        recorder.reset()
        viewModel.submitNamesRecording(fileURL: file)
    }
}
