import SwiftUI

// The approval queue for one routine. Each card is answered independently
// (approve / edit / deny, optional note); the answer is a local write on the
// server and the card flips to "answered — will be applied on the next
// run". answered ≠ applied is shown honestly (plan §6.4).

struct RoutineAsksView: View {
    private let routineSlug: String
    private let routineName: String
    /// Called with the ask id after the server accepts an answer, so the
    /// routine home's "Needs You" preview can drop it without a refetch.
    private let onAnswered: ((String) -> Void)?
    @StateObject private var viewModel: RoutineAsksViewModel
    @State private var showNotice = false

    init(routineSlug: String, routineName: String, onAnswered: ((String) -> Void)? = nil) {
        self.routineSlug = routineSlug
        self.routineName = routineName
        self.onAnswered = onAnswered
        _viewModel = StateObject(wrappedValue: RoutineAsksViewModel(routineSlug: routineSlug))
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            Group {
                if viewModel.isLoading && viewModel.asks.isEmpty {
                    ProgressView("Loading…")
                        .foregroundColor(Theme.textPrimary)
                } else if let error = viewModel.errorMessage, viewModel.asks.isEmpty {
                    VStack(spacing: Theme.spacingMD) {
                        Text(error)
                            .font(.system(size: Theme.fontSizeSM))
                            .foregroundColor(Theme.accent)
                            .multilineTextAlignment(.center)

                        Button("Retry") {
                            Task { await viewModel.load() }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(Theme.spacingLG)
                } else if viewModel.asks.isEmpty {
                    VStack(spacing: Theme.spacingMD) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 48))
                            .foregroundColor(Theme.success.opacity(0.7))
                        Text("Nothing to review")
                            .font(.system(size: Theme.fontSizeLG, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)
                        Text("When the routine needs a decision from you, it will show up here.")
                            .font(.system(size: Theme.fontSizeSM))
                            .foregroundColor(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(Theme.spacingLG)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: Theme.spacingMD) {
                            if !viewModel.openAsks.isEmpty {
                                sectionHeader("Needs You", count: viewModel.openAsks.count)
                                ForEach(viewModel.openAsks) { ask in
                                    RoutineAskCard(
                                        ask: ask,
                                        isSubmitting: viewModel.submittingAskIDs.contains(ask.askID)
                                    ) { choice, text in
                                        let accepted = await viewModel.answer(ask, choice: choice, text: text)
                                        if accepted {
                                            onAnswered?(ask.askID)
                                        }
                                        return accepted
                                    }
                                }
                            }

                            if !viewModel.resolvedAsks.isEmpty {
                                sectionHeader("Resolved", count: viewModel.resolvedAsks.count)
                                    .padding(.top, viewModel.openAsks.isEmpty ? 0 : Theme.spacingSM)
                                ForEach(viewModel.resolvedAsks) { ask in
                                    RoutineAskCard(ask: ask, isSubmitting: false) { _, _ in false }
                                }
                            }
                        }
                        .padding(.horizontal, Theme.spacingMD)
                        .padding(.vertical, Theme.spacingMD)
                    }
                    .refreshable {
                        await viewModel.load()
                    }
                }
            }
        }
        .navigationTitle("Asks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await viewModel.loadIfNeeded()
        }
        .onChange(of: viewModel.noticeMessage) { _, newValue in
            if newValue != nil {
                showNotice = true
            }
        }
        .alert(routineName, isPresented: $showNotice) {
            Button("OK", role: .cancel) {
                viewModel.noticeMessage = nil
            }
        } message: {
            Text(viewModel.noticeMessage ?? "")
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: Theme.spacingSM) {
            Text(title)
                .sectionLabel()
                .foregroundColor(Theme.textSecondary)
            Text("\(count)")
                .font(.system(size: Theme.fontSizeXS, weight: .semibold))
                .foregroundColor(Theme.textTertiary)
        }
        .padding(.horizontal, Theme.spacingXS)
    }
}

// MARK: - Card

struct RoutineAskCard: View {
    let ask: RoutineAsk
    let isSubmitting: Bool
    /// Returns true when the server accepted the answer.
    let onAnswer: (RoutineAnswerChoice, String?) async -> Bool

    @State private var isEditing = false
    @State private var editText = ""
    @State private var showNoteField = false
    @State private var noteText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSMPlus) {
            Text(ask.title)
                .font(.system(size: Theme.fontSizeMD, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)

            metaLine

            if let context = trimmed(ask.context) {
                labeledBlock("Why you", text: context)
            }
            if let rec = trimmed(ask.recommendation) {
                labeledBlock("Recommended", text: rec)
            }
            if let change = trimmed(ask.proposedChange) {
                VStack(alignment: .leading, spacing: Theme.spacingXS) {
                    Text("Proposed change")
                        .sectionLabel()
                        .foregroundColor(Theme.textTertiary)
                    // Opaque diff text — always plain, never markdown.
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(change)
                            .font(.system(size: Theme.fontSizeSM, design: .monospaced))
                            .foregroundColor(Theme.textPrimary)
                            .textSelection(.enabled)
                            .padding(Theme.spacingSMPlus)
                    }
                    .background(Theme.surface2)
                    .cornerRadius(Theme.cornerRadiusSM)
                }
            }
            if let safe = trimmed(ask.safeDefault) {
                labeledBlock("If you do nothing", text: safe)
            }

            if ask.isOpen {
                actions
            } else {
                resolvedStatus
            }
        }
        .cardStyle()
        .opacity(ask.isOpen ? 1 : 0.85)
    }

    private var metaLine: some View {
        HStack(spacing: Theme.spacingXS) {
            if let batch = trimmed(ask.batchID) {
                Text("Batch \(batch)")
                    .lineLimit(1)
            }
            if let ext = trimmed(ask.externalAskID) {
                if trimmed(ask.batchID) != nil { Text("·") }
                Text(ext)
                    .lineLimit(1)
            }
            if let created = RoutineDateParser.relative(ask.createdAt) {
                if trimmed(ask.batchID) != nil || trimmed(ask.externalAskID) != nil { Text("·") }
                Text(created)
            }
            if ask.supersedesAskID != nil {
                Text("·")
                Text("re-draft")
                    .foregroundColor(Theme.warning)
            }
        }
        .font(.system(size: Theme.fontSizeXS))
        .foregroundColor(Theme.textTertiary)
    }

    private func labeledBlock(_ label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacingXS) {
            Text(label)
                .sectionLabel()
                .foregroundColor(Theme.textTertiary)
            Text(text)
                .font(.system(size: Theme.fontSizeSM))
                .foregroundColor(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    // MARK: Open-ask actions

    @ViewBuilder
    private var actions: some View {
        if isEditing {
            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                Text("Your wording")
                    .sectionLabel()
                    .foregroundColor(Theme.textTertiary)

                TextEditor(text: $editText)
                    .font(.system(size: Theme.fontSizeSM))
                    .foregroundColor(Theme.textPrimary)
                    .frame(minHeight: 140)
                    .padding(Theme.spacingXS)
                    .scrollContentBackground(.hidden)
                    .background(Theme.surface2)
                    .cornerRadius(Theme.cornerRadiusSM)

                Text("Sent exactly as written. Replaces the proposed change.")
                    .font(.system(size: Theme.fontSizeXS))
                    .foregroundColor(Theme.textTertiary)

                HStack(spacing: Theme.spacingSM) {
                    AskActionButton(title: "Submit edit", style: .primary, isEnabled: editIsValid && !isSubmitting) {
                        Task {
                            if await onAnswer(.edit, editText) {
                                isEditing = false
                            }
                        }
                    }
                    AskActionButton(title: "Cancel", style: .secondary, isEnabled: !isSubmitting) {
                        isEditing = false
                    }
                    if isSubmitting {
                        ProgressView().controlSize(.small)
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                HStack(spacing: Theme.spacingSM) {
                    AskActionButton(title: "Approve", style: .primary, isEnabled: !isSubmitting) {
                        Task { await onAnswer(.approve, noteOrNil) }
                    }
                    AskActionButton(title: "Edit", style: .secondary, isEnabled: !isSubmitting) {
                        editText = ask.proposedChange ?? ""
                        isEditing = true
                    }
                    AskActionButton(title: "Deny", style: .destructive, isEnabled: !isSubmitting) {
                        Task { await onAnswer(.deny, noteOrNil) }
                    }
                    if isSubmitting {
                        ProgressView().controlSize(.small)
                    }
                    Spacer()
                }

                if showNoteField {
                    TextField("Add a note (optional)", text: $noteText, axis: .vertical)
                        .lineLimit(1...4)
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(Theme.textPrimary)
                        .padding(Theme.spacingSM)
                        .background(Theme.surface2)
                        .cornerRadius(Theme.cornerRadiusSM)
                } else {
                    Button("Add a note…") {
                        showNoteField = true
                    }
                    .font(.system(size: Theme.fontSizeXS))
                    .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }

    private var editIsValid: Bool {
        !editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var noteOrNil: String? {
        trimmed(noteText)
    }

    // MARK: Resolved status

    @ViewBuilder
    private var resolvedStatus: some View {
        VStack(alignment: .leading, spacing: Theme.spacingXS) {
            HStack(spacing: Theme.spacingSM) {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                Text(statusLine)
                    .font(.system(size: Theme.fontSizeSM, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
            }
            if let answer = trimmed(ask.answerText) {
                Text(answer)
                    .font(.system(size: Theme.fontSizeSM, design: ask.answerChoice == "edit" ? .monospaced : .default))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .padding(.top, Theme.spacingXS)
    }

    private var statusLine: String {
        let choice = ask.answerChoice ?? "answered"
        switch ask.askStatus {
        case .answered:
            let suffix = ask.answerChoice == "edit" ? " with your edits" : ""
            return "Answered — \(choice)\(suffix). Will be applied on the next run."
        case .applied:
            let when = RoutineDateParser.relative(ask.appliedAt).map { " \($0)" } ?? ""
            return "Applied\(when) — \(choice)."
        case .withdrawn:
            return "Withdrawn by the routine."
        default:
            return ask.status.capitalized
        }
    }

    private var statusIcon: String {
        switch ask.askStatus {
        case .answered: return "clock.badge.checkmark"
        case .applied: return "checkmark.circle.fill"
        case .withdrawn: return "xmark.circle"
        default: return "circle"
        }
    }

    private var statusColor: Color {
        switch ask.askStatus {
        case .answered: return Theme.info
        case .applied: return Theme.success
        case .withdrawn: return Theme.textTertiary
        default: return Theme.textSecondary
        }
    }

    private func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

// MARK: - Compact action button

private struct AskActionButton: View {
    enum Style { case primary, secondary, destructive }

    let title: String
    let style: Style
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: Theme.fontSizeSM, weight: .semibold))
                .foregroundColor(foreground)
                .padding(.horizontal, Theme.spacingMD)
                .padding(.vertical, Theme.spacingSM)
                .background(background)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusSM)
                        .stroke(style == .primary ? Color.clear : Theme.border, lineWidth: 1)
                )
                .cornerRadius(Theme.cornerRadiusSM)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }

    private var foreground: Color {
        switch style {
        case .primary: return Theme.background
        case .secondary: return Theme.textPrimary
        case .destructive: return Theme.accent
        }
    }

    private var background: Color {
        switch style {
        case .primary: return Theme.textPrimary
        case .secondary, .destructive: return Theme.surface2
        }
    }
}

#Preview {
    NavigationStack {
        RoutineAsksView(routineSlug: "example", routineName: "Example Routine")
    }
}
