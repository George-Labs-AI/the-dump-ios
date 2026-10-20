import SwiftUI
import PhotosUI

// MARK: - Screens 5 (you're done organizing), 6a, 6b and 6c (the first note)

struct OnboardingFirstNoteScreen: View {
    @ObservedObject var viewModel: OnboardingV2ViewModel
    let onLeave: () -> Void
    @Environment(\.openURL) private var openURL
    @State private var showChangePicker = false
    /// Screen 5c: while the first note is being typed, the stats and the
    /// category list make room for the keyboard; the headline stays.
    @State private var isTypingFirstNote = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                Group {
                    if viewModel.step == .done {
                        doneContent
                    } else if let note = viewModel.progress.firstNote {
                        noteContent(note)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, OnboardingStyle.gutter)
                .padding(.bottom, 24)
            }
            footer
                .padding(.horizontal, OnboardingStyle.gutter)
                .padding(.bottom, isTypingFirstNote ? 12 : 40)
        }
        .animation(.easeInOut(duration: 0.25), value: isTypingFirstNote)
        .task(id: viewModel.progress.firstNote?.fileUuid) {
            await viewModel.pollFirstNote()
        }
        .sheet(isPresented: $showChangePicker) {
            OnboardingChangeCategorySheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(OnboardingStyle.surface)
                .presentationCornerRadius(20)
        }
    }

    // MARK: Screen 5

    private var doneContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Text("You’re done organizing.")
                    .onboardingHeadline(52, lineHeight: 50)
                    .accessibilityAddTraits(.isHeader)
                Text("We built your categories from what you told us. From here, just dump.")
                    .onboardingBody()
            }
            .padding(.top, 48)

            if !isTypingFirstNote {
                HStack(alignment: .top, spacing: 8) {
                    stat(viewModel.savedCategoryCount, "Categories")
                    stat(viewModel.savedNameCount, "Names it knows")
                    stat(0, "Folders to manage", highlighted: true)
                }
                .padding(.top, 40)
                .transition(.opacity)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Your categories").onboardingLabel()
                    Text(viewModel.savedCategoryLine)
                        .onboardingBody(OnboardingStyle.text)
                        .lineSpacing(7)
                }
                .padding(.top, 36)
                .transition(.opacity)
            }
        }
    }

    /// One of the three stats; the last ("0 folders to manage") has a white
    /// rule and label.
    private func stat(_ value: Int, _ label: String, highlighted: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(value)")
                .font(OnboardingStyle.display(40))
                .tracking(OnboardingStyle.displayTracking(40))
                .monospacedDigit()
                .foregroundColor(OnboardingStyle.text)
            Text(label).onboardingLabel(highlighted ? OnboardingStyle.text : OnboardingStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 16)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(highlighted ? OnboardingStyle.text : OnboardingStyle.hairline)
                .frame(height: 0.5)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Screens 6a, 6b and 6c

    private func noteContent(_ note: OnboardingFirstNote) -> some View {
        VStack(alignment: .leading, spacing: 32) {
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
        .padding(.top, 40)
    }

    private func headline(for note: OnboardingFirstNote) -> String {
        switch note.status {
        case .processing: return "Got it."
        case .sorted: return "First one, sorted."
        case .failed: return "We couldn’t read that one."
        }
    }

    private func noteCard(_ note: OnboardingFirstNote) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            noteBody(note)
            switch note.status {
            case .processing:
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(OnboardingStyle.text)
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                    Text("Reading your note").onboardingLabel(OnboardingStyle.text)
                }
                .accessibilityElement(children: .combine)
            case .sorted:
                if let reason = note.visibleReason {
                    Text(reason)
                        .onboardingCaption()
                        .lineSpacing(3)
                }
                HStack {
                    Text("Sorted into \(note.categoryName ?? "")")
                        .onboardingLabel(OnboardingStyle.text)
                    Spacer()
                    if viewModel.isChangingCategory {
                        ProgressView().tint(OnboardingStyle.secondary).scaleEffect(0.7)
                    } else if note.organizedNoteId != nil {
                        Button("Change") { showChangePicker = true }
                            .buttonStyle(OnboardingLinkStyle())
                    }
                }
                if let error = viewModel.changeError {
                    Text(error).onboardingCaption(OnboardingStyle.danger)
                }
            case .failed:
                HStack(spacing: 8) {
                    Text("!")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(OnboardingStyle.text)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().strokeBorder(OnboardingStyle.text, lineWidth: 1.25))
                    Text("Couldn’t read it").onboardingLabel(OnboardingStyle.text)
                }
                .accessibilityElement(children: .combine)
                Text("This note didn’t go through. It’s on our side, not yours, and your categories are all set.")
                    .onboardingCaption()
                    .lineSpacing(3)
            }
        }
        .onboardingCard()
        .animation(.easeInOut(duration: 0.25), value: note.status)
    }

    /// What they sent: the text once there is some, otherwise (a photo or
    /// file that hasn't been read yet, or couldn't be) its icon and name.
    @ViewBuilder
    private func noteBody(_ note: OnboardingFirstNote) -> some View {
        let isFile = note.kind == .photo || note.kind == .file
        if isFile && (note.preview ?? "").isEmpty {
            HStack(spacing: 12) {
                Image(systemName: note.kind == .photo ? "photo" : "doc.text")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(OnboardingStyle.secondary)
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 10).fill(OnboardingStyle.hairline))
                Text(note.localText)
                    .font(OnboardingStyle.body)
                    .foregroundColor(OnboardingStyle.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        } else {
            Text(note.displayText)
                .onboardingBody(OnboardingStyle.text)
                .lineLimit(note.status == .failed ? 3 : 10)
        }
    }

    private func categoryRow(_ category: OnboardingSavedCategory) -> some View {
        let isLit = viewModel.isFirstNoteCategory(category)
        return HStack {
            Text(category.name)
                .font(isLit ? OnboardingStyle.bodyMedium : OnboardingStyle.body)
                .foregroundColor(isLit ? OnboardingStyle.text : OnboardingStyle.secondary)
            Spacer()
            Text(isLit ? "1" : "0")
                .font(isLit ? OnboardingStyle.captionMedium : OnboardingStyle.caption)
                .monospacedDigit()
                .foregroundColor(isLit ? OnboardingStyle.text : OnboardingStyle.secondary)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(OnboardingStyle.hairline).frame(height: 0.5)
        }
        .accessibilityElement(children: .combine)
        .animation(.easeInOut(duration: 0.3), value: isLit)
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        if viewModel.step == .done {
            OnboardingCaptureBar(viewModel: viewModel, isTyping: $isTypingFirstNote, onLeave: onLeave)
        } else if viewModel.progress.firstNote?.status == .failed {
            // 6c: one way forward, no retry; the categories are saved.
            Button("Go to my Dump", action: onLeave)
                .buttonStyle(OnboardingPrimaryButtonStyle())
        } else {
            VStack(spacing: 16) {
                leaveBar
                HStack {
                    if viewModel.progress.firstNote?.status == .sorted {
                        Button("Use your notes in Claude →") {
                            if let url = URL(string: SharedConstants.mcpSetupGuideURL) {
                                openURL(url)
                            }
                            onLeave()
                        }
                        .buttonStyle(OnboardingLinkStyle())
                    }
                    Spacer()
                    Button("Go to my Dump →", action: onLeave)
                        .buttonStyle(OnboardingLinkStyle(color: OnboardingStyle.text, font: OnboardingStyle.captionMedium))
                }
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
                    .foregroundColor(OnboardingStyle.placeholder)
                Spacer()
                Image(systemName: "mic")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(OnboardingStyle.background)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(OnboardingStyle.text))
            }
            .padding(.leading, 20)
            .padding(.trailing, 8)
            .frame(height: 56)
            .background(Capsule().fill(OnboardingStyle.surface))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dump something else")
        .accessibilityHint("Opens your Dump")
    }
}

// MARK: - Screen 5's capture bar (5, 5b, 5c)

/// "+" adds a photo or file, the label opens the keyboard (5c), and the mic
/// records right in the bar (5b). Any of them saves the first note and
/// moves to screen 6. The hint above the bar and the link under it change
/// with the bar.
struct OnboardingCaptureBar: View {
    @ObservedObject var viewModel: OnboardingV2ViewModel
    @Binding var isTyping: Bool
    let onLeave: () -> Void
    @StateObject private var recorder = AudioRecorderService()
    @State private var text = ""
    @State private var showSourceDialog = false
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var showFiles = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    @State private var micDenied = false
    /// Set the moment Send is tapped, before the save starts, so the
    /// keyboard closing on the way can't turn the bar back to its resting
    /// state and drop the note.
    @State private var isSending = false
    @FocusState private var isFocused: Bool

    private var isRecording: Bool { recorder.state == .recording }
    private var hasText: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 16) {
            if let hint {
                Text(hint)
                    .onboardingCaption()
                    .multilineTextAlignment(.center)
            }
            bar
                .frame(minHeight: 56)
                .background(RoundedRectangle(cornerRadius: 28).fill(OnboardingStyle.text))
            if micDenied {
                Text("The Dump can’t use your microphone. Type instead, or turn the mic on in Settings.")
                    .onboardingCaption()
                    .multilineTextAlignment(.center)
            }
            if let error = viewModel.firstNoteError {
                Text(error)
                    .onboardingCaption(OnboardingStyle.danger)
                    .multilineTextAlignment(.center)
            }
            link
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
            if isRecording, duration >= viewModel.recordingLimits.hardStopSeconds {
                stopRecording()
            }
        }
        .onChange(of: isFocused) { _, focused in
            // Tapping outside the box closes the keyboard and returns to 5,
            // keeping what was typed.
            if !focused && !isSending && !viewModel.isSavingFirstNote {
                isTyping = false
            }
        }
    }

    private var hint: String? {
        if isRecording { return "Listening. Tap stop when you’re done." }
        if isTyping || viewModel.isSavingFirstNote { return nil }
        return "Type, talk, or add a photo or file."
    }

    @ViewBuilder
    private var link: some View {
        if isRecording {
            Button("Cancel") { recorder.discardRecording() }
                .buttonStyle(OnboardingLinkStyle(color: OnboardingStyle.text, font: OnboardingStyle.captionMedium))
        } else if !isTyping {
            Button("Go to my Dump →", action: onLeave)
                .buttonStyle(OnboardingLinkStyle(color: OnboardingStyle.text, font: OnboardingStyle.captionMedium))
        }
    }

    @ViewBuilder
    private var bar: some View {
        if isRecording {
            recordingBar
        } else if viewModel.isSavingFirstNote {
            savingBar
        } else if isTyping {
            typingBar
        } else {
            restingBar
        }
    }

    /// Screen 5: "+" and "Start dumping" on the left, a black mic on the right.
    private var restingBar: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.clearFirstNoteError()
                showSourceDialog = true
            } label: {
                Text("+")
                    .font(.system(size: 20))
                    .foregroundColor(OnboardingStyle.background)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color(hex: "E5E5EA")))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add a photo or file")

            Button {
                viewModel.clearFirstNoteError()
                isTyping = true
                isFocused = true
            } label: {
                Text(hasText ? text : "Start dumping")
                    .font(OnboardingStyle.button)
                    .foregroundColor(OnboardingStyle.background)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Type a note")

            micButton
        }
        .padding(.horizontal, 8)
    }

    /// Screen 5c: a text box that grows to a few lines; the mic turns into a
    /// send arrow once there is any text.
    private var typingBar: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("", text: $text, prompt: Text("Start dumping").foregroundColor(OnboardingStyle.secondary), axis: .vertical)
                .font(.system(size: 17))
                .foregroundColor(OnboardingStyle.background)
                .tint(OnboardingStyle.background)
                .lineSpacing(3)
                .lineLimit(1...5)
                .focused($isFocused)
                .padding(.vertical, 8)
                .onAppear { isFocused = true }
                .accessibilityLabel("Your first note")
            if hasText {
                Button(action: sendText) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(OnboardingStyle.text)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(OnboardingStyle.background))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Save note")
            } else {
                micButton
            }
        }
        .padding(.vertical, 8)
        .padding(.leading, 20)
        .padding(.trailing, 8)
    }

    /// Screen 5b: a red dot, the time and live level bars, with the mic
    /// turned into a stop button. Stop saves the note; Cancel (under the
    /// bar) throws the recording away.
    private var recordingBar: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(OnboardingStyle.danger)
                .frame(width: 8, height: 8)
                .padding(.leading, 12)
                .accessibilityHidden(true)
            Text(OnboardingRecordingPrompt.clock(recorder.duration))
                .font(OnboardingStyle.button)
                .monospacedDigit()
                .foregroundColor(OnboardingStyle.background)
                .accessibilityLabel("Recording, \(OnboardingRecordingPrompt.clock(recorder.duration))")
            OnboardingLevelBars(level: recorder.level, style: .captureBar)
            Spacer(minLength: 0)
            Button(action: stopRecording) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(OnboardingStyle.text)
                    .frame(width: 14, height: 14)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(OnboardingStyle.background))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop and save")
        }
        .padding(.horizontal, 8)
    }

    private var savingBar: some View {
        HStack(spacing: 10) {
            ProgressView().tint(OnboardingStyle.background)
            Text("Saving…")
                .font(OnboardingStyle.button)
                .foregroundColor(OnboardingStyle.background)
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var micButton: some View {
        Button(action: startRecording) {
            Image(systemName: "mic")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(OnboardingStyle.text)
                .frame(width: 40, height: 40)
                .background(Circle().fill(OnboardingStyle.background))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Record a note")
    }

    private func sendText() {
        let note = text
        isSending = true
        Task {
            await viewModel.submitFirstText(note)
            isSending = false
            if viewModel.firstNoteError == nil {
                text = ""
                isTyping = false
            }
        }
    }

    private func startRecording() {
        viewModel.clearFirstNoteError()
        micDenied = false
        isFocused = false
        Task {
            guard await OnboardingMicrophone.isAllowed() else {
                micDenied = true
                isTyping = true
                isFocused = true
                return
            }
            do {
                try recorder.startRecording(sampleRate: 16_000)
                isTyping = false
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

// MARK: - "Change" on 6b (6d)

/// The category picker behind "Change": every category just made, in the
/// same order as on 6b, the current one ticked. Picking another saves the
/// move at once through `/api/edit_note` and closes the sheet; the sorter's
/// reason is hidden afterwards.
struct OnboardingChangeCategorySheet: View {
    @ObservedObject var viewModel: OnboardingV2ViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Move this note to").onboardingTitle()
                if let text = viewModel.progress.firstNote?.displayText {
                    Text(text)
                        .onboardingCaption()
                        .lineLimit(2)
                }
            }
            .padding(.top, 24)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(viewModel.progress.savedCategories) { category in
                        row(category)
                    }
                }
            }
            if let error = viewModel.changeError {
                Text(error).onboardingCaption(OnboardingStyle.danger)
            }
        }
        .padding(.horizontal, OnboardingStyle.gutter)
        .padding(.bottom, 24)
        .background(OnboardingStyle.surface.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
    }

    private func row(_ category: OnboardingSavedCategory) -> some View {
        let isCurrent = viewModel.isFirstNoteCategory(category)
        return Button {
            Task {
                await viewModel.changeFirstNoteCategory(to: category)
                if viewModel.changeError == nil { dismiss() }
            }
        } label: {
            HStack {
                Text(category.name)
                    .font(isCurrent ? OnboardingStyle.bodyMedium : OnboardingStyle.body)
                    .foregroundColor(isCurrent ? OnboardingStyle.text : OnboardingStyle.secondary)
                Spacer()
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(OnboardingStyle.text)
                    .opacity(isCurrent ? 1 : 0)
                    .frame(width: 20, alignment: .trailing)
            }
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) {
                Rectangle().fill(OnboardingStyle.hairline).frame(height: 0.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isChangingCategory)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}
