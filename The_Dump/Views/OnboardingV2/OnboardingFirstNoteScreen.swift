import SwiftUI
import PhotosUI

// MARK: - Screens 5 (you're done organizing), 6a and 6b (the first note)

struct OnboardingFirstNoteScreen: View {
    @ObservedObject var viewModel: OnboardingV2ViewModel
    let onLeave: () -> Void
    @Environment(\.openURL) private var openURL
    @State private var showChangePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if viewModel.step == .done {
                        doneHeader
                    } else if let note = viewModel.progress.firstNote {
                        noteHeader(note)
                    }
                }
                .padding(.horizontal, OnboardingStyle.gutter)
                .padding(.top, 48)
                .padding(.bottom, 24)
            }
            footer
                .padding(.horizontal, OnboardingStyle.gutter)
                .padding(.bottom, 32)
        }
        .task(id: viewModel.progress.firstNote?.fileUuid) {
            await viewModel.pollFirstNote()
        }
        .sheet(isPresented: $showChangePicker) {
            OnboardingChangeCategorySheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: Screen 5

    private var doneHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("You’re done organizing.")
                .onboardingHeadline()
                .accessibilityAddTraits(.isHeader)
            Text("We built your categories from what you told us. From here, just dump.")
                .onboardingBody()
            HStack(alignment: .top, spacing: 16) {
                stat(viewModel.savedCategoryCount, "Categories")
                stat(viewModel.savedNameCount, "Names it knows")
                stat(0, "Folders to manage")
            }
            .padding(.top, 24)
            VStack(alignment: .leading, spacing: 10) {
                Text("Your categories").onboardingLabel()
                Text(viewModel.savedCategoryLine)
                    .onboardingBody(OnboardingStyle.text)
            }
            .padding(.top, 24)
        }
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(value)")
                .font(OnboardingStyle.display(34))
                .tracking(OnboardingStyle.displayTracking(34))
                .foregroundColor(OnboardingStyle.text)
            Text(label).onboardingLabel()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Screens 6a and 6b

    private func noteHeader(_ note: OnboardingFirstNote) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(headline(for: note))
                .onboardingHeadline()
                .accessibilityAddTraits(.isHeader)
            noteCard(note)
            VStack(alignment: .leading, spacing: 0) {
                Text("Your categories")
                    .onboardingLabel()
                    .padding(.bottom, 8)
                ForEach(viewModel.progress.savedCategories) { category in
                    categoryRow(category)
                }
            }
        }
    }

    private func headline(for note: OnboardingFirstNote) -> String {
        switch note.status {
        case .processing: return "Got it."
        case .sorted: return "First one, sorted."
        case .failed: return "We couldn’t read that one"
        }
    }

    private func noteCard(_ note: OnboardingFirstNote) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if (note.kind == .photo || note.kind == .file) && note.status == .processing && (note.preview ?? "").isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: note.kind == .photo ? "photo" : "doc")
                        .font(.system(size: 18))
                        .foregroundColor(OnboardingStyle.secondary)
                    Text(note.localText)
                        .onboardingBody(OnboardingStyle.text)
                        .lineLimit(1)
                }
            } else {
                Text(note.displayText)
                    .onboardingBody(OnboardingStyle.text)
                    .lineLimit(8)
            }
            switch note.status {
            case .processing:
                HStack(spacing: 10) {
                    ProgressView().tint(OnboardingStyle.secondary).scaleEffect(0.8)
                    Text("Reading your note").onboardingLabel()
                }
                .accessibilityElement(children: .combine)
            case .sorted:
                if let reason = note.visibleReason {
                    Text(reason).onboardingCaption()
                }
                HStack {
                    Text("Sorted into \(note.categoryName ?? "")").onboardingLabel(OnboardingStyle.text)
                    Spacer()
                    if viewModel.isChangingCategory {
                        ProgressView().tint(OnboardingStyle.secondary)
                    } else if note.organizedNoteId != nil {
                        Button("Change") { showChangePicker = true }
                            .buttonStyle(OnboardingLinkStyle(color: OnboardingStyle.text))
                    }
                }
                if let error = viewModel.changeError {
                    Text(error).onboardingCaption(OnboardingStyle.danger)
                }
            case .failed:
                Text("Something in it couldn’t be read. You can find it in your Dump.")
                    .onboardingCaption()
            }
        }
        .onboardingCard()
        .animation(.easeInOut(duration: 0.25), value: note.status)
    }

    private func categoryRow(_ category: OnboardingSavedCategory) -> some View {
        let isLit = viewModel.isFirstNoteCategory(category)
        return HStack {
            Text(category.name)
                .font(OnboardingStyle.body)
                .foregroundColor(isLit ? OnboardingStyle.text : OnboardingStyle.secondary)
            Spacer()
            Text(isLit ? "1" : "0")
                .font(OnboardingStyle.body)
                .monospacedDigit()
                .foregroundColor(isLit ? OnboardingStyle.text : OnboardingStyle.secondary)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(OnboardingStyle.hairline).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        if viewModel.step == .done {
            VStack(alignment: .leading, spacing: 12) {
                Text("Type, talk, or add a photo or file.")
                    .onboardingCaption()
                OnboardingCaptureBar(viewModel: viewModel)
                HStack {
                    Spacer()
                    goToDump
                }
                .padding(.top, 8)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                leaveBar
                HStack {
                    if viewModel.progress.firstNote?.status == .sorted {
                        Button("Use your notes in Claude →") {
                            if let url = URL(string: SharedConstants.mcpSetupGuideURL) {
                                openURL(url)
                            }
                            onLeave()
                        }
                        .buttonStyle(OnboardingLinkStyle(color: OnboardingStyle.text))
                    }
                    Spacer()
                    goToDump
                }
                .padding(.top, 8)
            }
        }
    }

    /// 6a and 6b's capture bar. Only the first note is special, so this one
    /// leaves onboarding for the main Dump screen (D-024).
    private var leaveBar: some View {
        Button(action: onLeave) {
            HStack {
                Text("Dump something else…")
                    .font(OnboardingStyle.body)
                    .foregroundColor(OnboardingStyle.secondary)
                Spacer()
                Image(systemName: "mic")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(OnboardingStyle.text)
            }
            .padding(.horizontal, 20)
            .frame(height: 56)
            .background(Capsule().fill(OnboardingStyle.surface))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var goToDump: some View {
        Button("Go to my Dump →", action: onLeave)
            .buttonStyle(OnboardingLinkStyle(color: OnboardingStyle.text))
    }
}

// MARK: - Screen 5's capture bar

/// "+" adds a photo or file, the label opens the keyboard, and the mic
/// records. Any of them saves the first note and moves to screen 6.
struct OnboardingCaptureBar: View {
    @ObservedObject var viewModel: OnboardingV2ViewModel
    @StateObject private var recorder = AudioRecorderService()
    @State private var isTyping = false
    @State private var text = ""
    @State private var showSourceDialog = false
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var showFiles = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    @State private var micDenied = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if recorder.state == .recording {
                    recordingBar
                } else if viewModel.isSavingFirstNote {
                    savingBar
                } else if isTyping {
                    typingBar
                } else {
                    restingBar
                }
            }
            .frame(minHeight: 56)
            .background(RoundedRectangle(cornerRadius: 28).fill(OnboardingStyle.surface))

            if micDenied {
                Text("The Dump can’t use your microphone. Type instead, or turn the mic on in Settings.")
                    .onboardingCaption()
            }
            if let error = viewModel.firstNoteError {
                Text(error).onboardingCaption(OnboardingStyle.danger)
            }
        }
        .confirmationDialog("Add a photo or file", isPresented: $showSourceDialog) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take a photo") { showCamera = true }
            }
            Button("Choose a photo") { showLibrary = true }
            Button("Choose a file") { showFiles = true }
        }
        .sheet(isPresented: $showCamera) {
            CameraView(image: $capturedImage)
        }
        .photosPicker(isPresented: $showLibrary, selection: $libraryItem, matching: .images)
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.item]) { result in
            guard case .success(let url) = result else { return }
            Task { await submitFile(url) }
        }
        .onChange(of: capturedImage) { _, image in
            guard let image else { return }
            capturedImage = nil
            Task { await viewModel.submitFirstPhoto(image) }
        }
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            libraryItem = nil
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                await viewModel.submitFirstPhoto(image.fixedOrientation())
            }
        }
        .onChange(of: recorder.duration) { _, duration in
            if recorder.state == .recording, duration >= viewModel.recordingLimits.hardStopSeconds {
                stopRecording()
            }
        }
    }

    private var restingBar: some View {
        HStack(spacing: 0) {
            Button {
                viewModel.clearFirstNoteError()
                showSourceDialog = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(OnboardingStyle.text)
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add a photo or file")

            Button {
                viewModel.clearFirstNoteError()
                isTyping = true
            } label: {
                Text("Start dumping")
                    .font(OnboardingStyle.body)
                    .foregroundColor(OnboardingStyle.secondary)
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Type a note")

            Button(action: startRecording) {
                Image(systemName: "mic")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(OnboardingStyle.text)
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Record a note")
        }
    }

    private var typingBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("", text: $text, prompt: Text("Start dumping").foregroundColor(OnboardingStyle.placeholder), axis: .vertical)
                .font(OnboardingStyle.body)
                .foregroundColor(OnboardingStyle.text)
                .lineLimit(1...6)
                .focused($isFocused)
                .padding(.leading, 20)
                .padding(.vertical, 17)
                .onAppear { isFocused = true }
            Button {
                let note = text
                isFocused = false
                Task {
                    await viewModel.submitFirstText(note)
                    if viewModel.firstNoteError == nil {
                        text = ""
                        isTyping = false
                    }
                }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(OnboardingStyle.background)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(OnboardingStyle.text))
            }
            .buttonStyle(.plain)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(10)
            .accessibilityLabel("Save note")
        }
    }

    private var recordingBar: some View {
        HStack(spacing: 12) {
            Text(OnboardingRecordingPrompt.clock(recorder.duration))
                .font(OnboardingStyle.bodyMedium)
                .monospacedDigit()
                .foregroundColor(OnboardingStyle.text)
                .padding(.leading, 20)
            OnboardingLevelBars(level: recorder.level)
                .scaleEffect(0.7, anchor: .leading)
            Spacer()
            Button("Cancel") {
                recorder.discardRecording()
            }
            .buttonStyle(OnboardingLinkStyle())
            Button(action: stopRecording) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(OnboardingStyle.background)
                    .frame(width: 12, height: 12)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(OnboardingStyle.text))
            }
            .buttonStyle(.plain)
            .padding(10)
            .accessibilityLabel("Stop and save")
        }
    }

    private var savingBar: some View {
        HStack(spacing: 10) {
            ProgressView().tint(OnboardingStyle.secondary)
            Text("Saving…").onboardingCaption()
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private func startRecording() {
        viewModel.clearFirstNoteError()
        micDenied = false
        Task {
            guard await OnboardingMicrophone.isAllowed() else {
                micDenied = true
                isTyping = true
                return
            }
            do {
                try recorder.startRecording(sampleRate: 16_000)
            } catch {
                recorder.reset()
            }
        }
    }

    private func stopRecording() {
        guard let file = recorder.currentFileURL else { return }
        recorder.stopRecording()
        recorder.reset()
        Task { await viewModel.submitFirstRecording(fileURL: file) }
    }

    private func submitFile(_ url: URL) async {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart { url.stopAccessingSecurityScopedResource() }
        }
        await viewModel.submitFirstFile(url)
    }
}

// MARK: - "Change" on 6b

/// The category picker behind "Change". Picking one moves the note through
/// `/api/edit_note`; the sorter's reason is hidden afterwards.
struct OnboardingChangeCategorySheet: View {
    @ObservedObject var viewModel: OnboardingV2ViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Move it to").onboardingLabel()
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(OnboardingLinkStyle(color: OnboardingStyle.text, font: OnboardingStyle.body))
            }
            .padding(.horizontal, OnboardingStyle.gutter)
            .frame(height: 56)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(viewModel.progress.savedCategories) { category in
                        Button {
                            Task {
                                await viewModel.changeFirstNoteCategory(to: category)
                                if viewModel.changeError == nil { dismiss() }
                            }
                        } label: {
                            HStack {
                                Text(category.name)
                                    .font(OnboardingStyle.body)
                                    .foregroundColor(OnboardingStyle.text)
                                Spacer()
                                if viewModel.isFirstNoteCategory(category) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(OnboardingStyle.text)
                                }
                            }
                            .padding(.vertical, 16)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(OnboardingStyle.hairline).frame(height: 1)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isChangingCategory)
                    }
                }
                .padding(.horizontal, OnboardingStyle.gutter)
            }
        }
        .background(OnboardingStyle.background.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
    }
}
