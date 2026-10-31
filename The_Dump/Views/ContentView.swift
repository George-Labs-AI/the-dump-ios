import SwiftUI
import Combine
import PhotosUI
import UniformTypeIdentifiers

// this is the view page that defines the other views
// learned that @ is not a decorator but a property wrapper
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var pendingNotesViewModel = PendingNotesViewModel()
    // @state makes sure what the variable is set to doesn't change just becuase the code reloads, and state is often used for things that a user may change
    @State private var showPhotoSourceDialog = false
    @State private var showCamera = false
    @State private var showPhotoLibraryPicker = false
    @State private var selectedLibraryItems: [PhotosPickerItem] = []
    @State private var showVoiceMemo = false
    @State private var showSettings = false
    @State private var showConnectToClaude = false
    @State private var showFilePicker = false
    @State private var showTextNote = false
    @State private var showPaywall = false
    @State private var capturedImage: UIImage?
    @State private var showErrorAlert = false
    @State private var errorAlertTitle = ""
    @State private var errorAlertMessage = ""
    /// Set by Open on an organized Processing row; pushes that note.
    @State private var openedNoteID: String?
    /// The "Send notes from Claude or ChatGPT" card stays closed once its ×
    /// is tapped.
    @AppStorage("dumpClaudeHintDismissed") private var isClaudeHintDismissed = false
    
// a view is a type of struct that is called out as a view, and it must provide a body variable that contains the layout
    // "some" view is used to not have to tell the compiler the exact type name of what is in the view, since it would be too complex. There can only be one body property per View
    
    var body: some View {
        // navigation stack is like a history so the app remembers where you came from to populate values that rely on previos screen actions
        NavigationStack {
            VStack(spacing: 0) {
                topBar

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

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Your Dump")
                            .tdHeadline()
                            .foregroundStyle(Theme.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                            .padding(.bottom, Theme.spacingLG)

                        if !isClaudeHintDismissed {
                            ClaudeHintCard(
                                onOpen: { showConnectToClaude = true },
                                onDismiss: { isClaudeHintDismissed = true }
                            )
                        }

                        // One Processing section holds both: captures still
                        // uploading (session rows), then captures the server
                        // is working on (pending-note records, note-status
                        // contract Phase 1). Session rows are removed on
                        // upload success, so each capture shows once (modulo
                        // a 1-2 frame gap while the view model mirrors the
                        // store).
                        if !sessionStore.items.isEmpty || !pendingNotesViewModel.records.isEmpty {
                            ProcessingSection(
                                sessionItems: sessionStore.items,
                                records: pendingNotesViewModel.records,
                                onDismissUpload: { id in
                                    sessionStore.removeItem(id: id)
                                },
                                onOpen: { record in
                                    // Opening an organized note also clears
                                    // its row.
                                    openedNoteID = record.openableNoteId
                                    pendingNotesViewModel.acknowledge(fileUuid: record.fileUuid)
                                },
                                onAcknowledge: { fileUuid in
                                    pendingNotesViewModel.acknowledge(fileUuid: fileUuid)
                                }
                            )
                            .padding(.top, Theme.spacingXL)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.screenH)
                    .padding(.top, Theme.spacingSM)
                    .padding(.bottom, Theme.spacingLG)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            // The capture bar sits above the tab bar, which .appTabBar()
            // adds below it.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CaptureBar(
                    photoSourceDialogPresented: $showPhotoSourceDialog,
                    onPhotoTap: { guardCapture { showPhotoSourceDialog = true } },
                    onTakePhoto: { showCamera = true },
                    onChooseFromLibrary: { showPhotoLibraryPicker = true },
                    onFileTap: { guardCapture { showFilePicker = true } },
                    onTextTap: { guardCapture { showTextNote = true } },
                    onVoiceTap: { guardCapture { showVoiceMemo = true } }
                )
            }
            .appTabBar()
            .toolbar(.hidden, for: .navigationBar)
        // Photo has two sources: the camera, or the photo library (where
        // screenshots and saved images live — the Files picker can't see
        // those). The library picker runs out of process, so it needs no
        // photo-library permission prompt. The source dialog itself is
        // attached to the "+" menu in CaptureBar so that where iOS presents
        // it as a popover it anchors to that button.
        .sheet(isPresented: $showCamera) {
            CameraView(image: $capturedImage)
        }
        .photosPicker(
            isPresented: $showPhotoLibraryPicker,
            selection: $selectedLibraryItems,
            maxSelectionCount: Self.maxLibrarySelection,
            matching: .images
        )
        .onChange(of: selectedLibraryItems) { _, items in
            guard !items.isEmpty else { return }
            handleLibrarySelection(items)
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
        .sheet(isPresented: $showConnectToClaude) {
            NavigationStack {
                ConnectToClaudeView(showsDoneButton: true)
            }
        }
        // Every file stays pickable ([.item]) so that a video or zip gets a
        // clear "not supported" message instead of just being greyed out;
        // the type check happens in handleSelectedFiles.
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                handleSelectedFiles(urls)
            case .failure(let error):
                showError("File selection failed: \(error.localizedDescription)")
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
        .navigationDestination(item: $openedNoteID) { noteID in
            NoteDetailView(noteID: noteID)
        }
        .environmentObject(sessionStore)
        .alert(errorAlertTitle, isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorAlertMessage)
        }
    }
    }

    /// Settings sits alone at the right of a 44pt bar (Paper, 01 Dump).
    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: Theme.touchMin, height: Theme.touchMin)
                    .contentShape(Rectangle())
            }
            .buttonStyle(TDPressStyle())
            .accessibilityLabel("Settings")
        }
        .frame(height: 44)
        .padding(.horizontal, Theme.spacingSMPlus)
    }

    /// Upper bound on photos picked from the library in one go. Each one
    /// becomes its own upload and its own note; this just keeps a single
    /// batch from tying up the device for too long.
    static let maxLibrarySelection = 10

    private func guardCapture(_ action: () -> Void) {
        if appState.subscriptionViewModel.isBlocked {
            showPaywall = true
        } else {
            action()
        }
    }

    private func showError(_ message: String, title: String = "Something went wrong") {
        errorAlertTitle = title
        errorAlertMessage = message
        showErrorAlert = true
    }
    
    private func handleCapturedPhoto(_ image: UIImage) {
        Task {
            await uploadPhoto(image)
        }
    }

    /// Library selections: first pull the encoded bytes of every pick while
    /// the picker selection is still live (the items' loaders are tied to
    /// it), then clear the selection, then decode and upload one at a time.
    /// Encoded photos are a few MB each, so holding up to 10 is fine; a
    /// decoded 12MP image is ~48MB, so only one of those exists at a time.
    /// Each photo becomes its own upload with its own uuid, so each becomes
    /// its own note.
    private func handleLibrarySelection(_ items: [PhotosPickerItem]) {
        Task {
            var failedCount = 0
            var encodedPhotos: [Data] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    encodedPhotos.append(data)
                } else {
                    failedCount += 1
                }
            }
            // Cleared only now so re-opening the picker starts empty; the
            // guard in onChange ignores this reset.
            selectedLibraryItems = []

            for data in encodedPhotos {
                guard let image = UIImage(data: data) else {
                    failedCount += 1
                    continue
                }
                await uploadPhoto(image.fixedOrientation())
            }
            if failedCount > 0 {
                showError(failedCount == 1
                    ? "One photo couldn't be read and was skipped."
                    : "\(failedCount) photos couldn't be read and were skipped.")
            }
        }
    }

    /// Shared by the camera and library paths. Adds a transient session row,
    /// uploads, and hands off to the Processing row on success.
    private func uploadPhoto(_ image: UIImage) async {
        guard let email = appState.userEmail,
              let idToken = await appState.idToken else {
            showError(Self.cannotUploadMessage)
            return
        }

        let item = SessionItem(
            kind: .photo,
            originalFilename: "photo_\(UUID().uuidString).jpg",
            status: .uploading
        )

        sessionStore.addItem(item)

        do {
            _ = try await UploadService.shared.uploadPhoto(
                image: image,
                userEmail: email,
                idToken: idToken,
                onProgress: progressHandler(for: item.id)
            )
            // The PendingNoteRecord is added before uploadPhoto returns,
            // so the Processing row replaces this transient one — remove
            // it instead of showing "Captured!" for 8s alongside.
            sessionStore.removeItem(id: item.id)
        } catch {
            sessionStore.markFailed(id: item.id, error: error.localizedDescription)
        }
    }

    /// Feeds an upload's progress, which arrives off the main thread, to its
    /// row's bar.
    private func progressHandler(for sessionItemID: String) -> UploadProgressHandler {
        { [sessionStore] progress in
            Task { @MainActor in
                sessionStore.updateProgress(id: sessionItemID, progress: progress)
            }
        }
    }

    private static let cannotUploadMessage = "Unable to upload. Please check your connection and try again."

    /// Files picker selections. Types the server can't read (videos, zips,
    /// anything off the web's list) are turned away first with one message
    /// naming them. Each remaining file gets its own row straight away, so
    /// the whole pick is visible, then uploads one at a time (each file is
    /// read fully into memory, up to 100MB) and becomes its own note.
    private func handleSelectedFiles(_ urls: [URL]) {
        let notice = CaptureFileTypes.skippedNotice(forFilenames: urls.map(\.lastPathComponent))
        if let notice {
            showError(notice.message, title: notice.title)
        }
        let accepted = urls.filter { CaptureFileTypes.rejection(forFilename: $0.lastPathComponent) == nil }
        guard !accepted.isEmpty else { return }

        // Picked files are security-scoped. Start access for every file now,
        // while the picker's grant is fresh, and hold it until the uploads
        // are done: files upload one at a time, so a later file can wait a
        // long while before its own upload starts.
        let accessStarted = accepted.map { $0.startAccessingSecurityScopedResource() }

        Task {
            defer {
                for (url, started) in zip(accepted, accessStarted) where started {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            guard appState.userEmail != nil, await appState.idToken != nil else {
                // Both alerts share one slot, so say both things at once
                // rather than replacing the list of files turned away.
                if let notice {
                    showError("\(notice.message)\n\n\(Self.cannotUploadMessage)", title: notice.title)
                } else {
                    showError(Self.cannotUploadMessage)
                }
                return
            }

            let items = accepted.map { url in
                SessionItem(
                    kind: .file,
                    originalFilename: url.lastPathComponent,
                    localFileURL: url,
                    status: .uploading
                )
            }
            for item in items {
                sessionStore.addItem(item)
            }
            for (item, url) in zip(items, accepted) {
                await uploadFile(url, sessionItemID: item.id)
            }
        }
    }

    private func uploadFile(_ url: URL, sessionItemID: String) async {
        // Fetched per file: Firebase refreshes the token if an earlier,
        // large upload took long enough for it to expire.
        guard let email = appState.userEmail,
              let idToken = await appState.idToken else {
            sessionStore.markFailed(id: sessionItemID, error: Self.cannotUploadMessage)
            return
        }

        do {
            _ = try await UploadService.shared.uploadFile(
                fileURL: url,
                userEmail: email,
                idToken: idToken,
                onProgress: progressHandler(for: sessionItemID)
            )
            // Hand off to the Processing row (see uploadPhoto).
            sessionStore.removeItem(id: sessionItemID)
        } catch {
            sessionStore.markFailed(id: sessionItemID, error: error.localizedDescription)
        }
    }
}

// MARK: - Subviews

/// The bar at the bottom of the Dump tab (Paper, 01 Dump): a field that opens
/// the note sheet, with "+" for a photo or file, and the white mic for voice.
struct CaptureBar: View {
    /// Drives the "Add a photo" source dialog, attached to the "+" button.
    @Binding var photoSourceDialogPresented: Bool
    let onPhotoTap: () -> Void
    let onTakePhoto: () -> Void
    let onChooseFromLibrary: () -> Void
    let onFileTap: () -> Void
    let onTextTap: () -> Void
    let onVoiceTap: () -> Void

    var body: some View {
        HStack(spacing: Theme.spacingSM) {
            HStack(spacing: 0) {
                Menu {
                    Button(action: onPhotoTap) {
                        Label("Photo", systemImage: "photo")
                    }
                    Button(action: onFileTap) {
                        Label("File", systemImage: "doc")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: Theme.touchMin, height: Theme.touchMin)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Add a photo or file")
                .confirmationDialog(
                    "Add a photo",
                    isPresented: $photoSourceDialogPresented,
                    titleVisibility: .visible
                ) {
                    Button("Take Photo", action: onTakePhoto)
                    Button("Choose from Library", action: onChooseFromLibrary)
                    Button("Cancel", role: .cancel) {}
                }

                Button(action: onTextTap) {
                    Text("Dump something…")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.placeholder)
                        .padding(.horizontal, Theme.spacingXS)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(TDPressStyle())
                .accessibilityLabel("Write a note")
            }
            .padding(.leading, 6)
            .padding(.trailing, Theme.spacingSMPlus)
            .frame(height: Theme.buttonHeight)
            .background(Capsule().fill(Theme.surface))

            Button(action: onVoiceTap) {
                Image(systemName: "mic")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Theme.buttonPrimaryForeground)
                    .frame(width: Theme.buttonHeight, height: Theme.buttonHeight)
                    .background(Circle().fill(Theme.buttonPrimaryBackground))
                    .contentShape(Circle())
            }
            .buttonStyle(TDPressStyle(pressedOpacity: 0.7))
            .accessibilityLabel("Record a voice note")
        }
        .padding(.horizontal, Theme.screenH)
        .padding(.top, Theme.spacingSM)
        .padding(.bottom, Theme.spacingSMPlus)
        .background(Theme.background)
    }
}

/// The card that points to the Claude setup screen. Tapping it opens that
/// screen; the × closes the card for good.
struct ClaudeHintCard: View {
    let onOpen: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: Theme.spacingSMPlus) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 18, height: 18)
                        .padding(.top, 3)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        // The padding gives each line Paper's full line
                        // box: 24 for the title, 18 for the caption.
                        Text("Send notes from Claude or ChatGPT.")
                            .tdBody()
                            .padding(.vertical, 2.5)
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Set it up in Settings → Connect to Claude.")
                            .tdCaption()
                            .padding(.vertical, 1.25)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(TDPressStyle())
            .accessibilityHint("Opens the Connect to Claude setup")

            // Paper draws it in a 32pt slot; it is tapped as 44pt, using the
            // card's right padding.
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: Theme.touchMin, height: Theme.touchMin)
                    .contentShape(Rectangle())
            }
            .buttonStyle(TDPressStyle())
            .padding(.top, -Theme.spacingSMPlus)
            .accessibilityLabel("Dismiss")
        }
        .padding(.vertical, Theme.spacingMD)
        .padding(.leading, Theme.spacingMD)
        .padding(.trailing, 3)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusCard)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }
}

/// The Dump tab's Processing list: captures still uploading, then captures
/// the server is working on, as flat rows with hairlines between them. Both
/// kinds use the same words (ProcessingStatusText).
struct ProcessingSection: View {
    let sessionItems: [SessionItem]
    let records: [PendingNoteRecord]
    /// Session item id of a failed upload the user dismissed.
    let onDismissUpload: (String) -> Void
    /// Open on an organized row.
    let onOpen: (PendingNoteRecord) -> Void
    /// File uuid of a row the user dismissed.
    let onAcknowledge: (String) -> Void

    private enum Entry: Identifiable {
        case upload(SessionItem)
        case note(PendingNoteRecord)

        var id: String {
            switch self {
            case .upload(let item): return "upload-\(item.id)"
            case .note(let record): return "note-\(record.id)"
            }
        }
    }

    private var entries: [Entry] {
        sessionItems.map(Entry.upload) + records.map(Entry.note)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TDSectionLabel(title: "Processing")
                .padding(.bottom, Theme.spacingXS)

            ForEach(entries) { entry in
                if entry.id != entries.first?.id {
                    TDHairline()
                }
                switch entry {
                case .upload(let item):
                    SessionItemRow(item: item) {
                        onDismissUpload(item.id)
                    }
                case .note(let record):
                    PendingNoteRow(
                        record: record,
                        onOpen: { onOpen(record) },
                        onAcknowledge: { onAcknowledge(record.fileUuid) }
                    )
                }
            }
        }
    }
}

/// One Processing row: the kind of capture as a small icon, then its title,
/// its status pill and anything under the pill.
private struct ProcessingRowLayout<Below: View>: View {
    let systemImage: String
    let title: String
    @ViewBuilder let below: () -> Below

    var body: some View {
        HStack(alignment: .top, spacing: Theme.spacingSMPlus) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 18, height: 18)
                .padding(.top, 3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                Text(title)
                    .tdBody()
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .frame(minHeight: 24, alignment: .leading)
                below()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Theme.spacingSMPlus)
    }
}

/// Small text buttons under a pill ("Open", "Dismiss"). Each keeps a 44pt
/// hit area but lays out at Paper's 32pt, so the hit area overlaps 6pt of
/// the gap above and of the row's padding below.
private struct ProcessingRowActions<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: Theme.spacingSMPlus) {
            content()
        }
        .padding(.vertical, -6)
    }
}

private func rowAction(_ title: String, primary: Bool = false, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .padding(.horizontal, Theme.spacingXS)
    }
    .buttonStyle(TDTextLinkStyle(color: primary ? Theme.textPrimary : Theme.textSecondary, size: 13))
}

/// A capture still on its way to the server.
struct SessionItemRow: View {
    let item: SessionItem
    /// The dismiss button on a failed upload.
    let onDismiss: () -> Void

    var body: some View {
        ProcessingRowLayout(systemImage: iconForKind, title: title) {
            switch item.status {
            case .pending, .uploading:
                TDStatusPill(mark: .symbol("arrow.up"), text: ProcessingStatusText.uploading)
                if let progress = item.progress {
                    TDMeter(value: progress)
                }
            case .captured:
                TDStatusPill(mark: .symbol("checkmark"), text: ProcessingStatusText.text(for: item.status))
            case .failed(let error):
                // The upload's own error (such as the 100MB limit) goes
                // under the pill; it can be too long for one.
                TDStatusPill(mark: .symbol("exclamationmark.circle"), text: "Couldn't upload")
                Text(error)
                    .tdCaption()
                    .foregroundStyle(Theme.textSecondary)
                ProcessingRowActions {
                    rowAction("Dismiss", action: onDismiss)
                }
            }
        }
    }

    private var iconForKind: String {
        switch item.kind {
        case .photo: return "photo"
        case .audio: return "mic"
        case .file: return "doc"
        case .text: return "text.alignleft"
        }
    }

    private var title: String {
        switch item.kind {
        case .photo: return "Photo"
        case .audio: return "Voice"
        case .file: return item.originalFilename
        case .text: return "Note"
        }
    }
}

/// A capture the server has received, from upload to organized.
struct PendingNoteRow: View {
    let record: PendingNoteRecord
    /// Open on an organized row.
    let onOpen: () -> Void
    /// Dismiss on an organized or failed row.
    let onAcknowledge: () -> Void

    var body: some View {
        ProcessingRowLayout(systemImage: iconForKind, title: primaryText) {
            switch record.lifecycleStatus {
            case .uploaded, .transcribed:
                TDStatusPill(mark: .dot, text: ProcessingStatusText.text(for: record))
            case .organized:
                // Amber: the note just landed in one of your categories.
                TDStatusPill(mark: .symbol("checkmark"), text: ProcessingStatusText.text(for: record), isYourStuff: true)
                ProcessingRowActions {
                    if record.openableNoteId != nil {
                        rowAction("Open", primary: true, action: onOpen)
                    }
                    rowAction("Dismiss", action: onAcknowledge)
                }
            case .failed:
                TDStatusPill(mark: .symbol("exclamationmark.circle"), text: ProcessingStatusText.text(for: record))
                ProcessingRowActions {
                    rowAction("Dismiss", action: onAcknowledge)
                }
            }
        }
    }

    private var iconForKind: String {
        switch record.kind {
        case .photo: return "photo"
        case .voice: return "mic"
        case .file: return "doc"
        case .text: return "text.alignleft"
        }
    }

    private var kindLabel: String {
        switch record.kind {
        case .photo: return "Photo"
        case .voice: return "Voice"
        case .file: return "File"
        case .text: return "Note"
        }
    }

    /// Typed notes show what the user typed immediately, regardless of
    /// status. Voice/photo/file show a kind label until the transcribed
    /// preview arrives, and the note's title once it is organized. The
    /// preview is raw markdown (e.g. "*Image (photo):* A close-up…"), so it
    /// is shown as plain text.
    private var primaryText: String {
        if record.kind == .text, let text = record.localText, !text.isEmpty {
            return text
        }
        if record.lifecycleStatus == .organized, let title = record.title, !title.isEmpty {
            return title
        }
        if let preview = record.transcribedPreview.map(PlainTextPreview.text(from:)), !preview.isEmpty {
            return preview
        }
        return kindLabel
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
