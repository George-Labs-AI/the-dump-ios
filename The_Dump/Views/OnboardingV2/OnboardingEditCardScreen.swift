import SwiftUI

// MARK: - Screens 4b (edit a category), 4c (add one) and 4d (its errors)

/// Everything on a card is editable here. Nothing reaches the account until
/// Finish; Save marks the card approved, Cancel throws the edits away.
struct OnboardingEditCardScreen: View {
    @ObservedObject var viewModel: OnboardingV2ViewModel
    let card: OnboardingCard
    let isNew: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var description: String
    @State private var names: [String]
    @State private var examples: [String]
    /// Shown only after Save was tapped, and each clears as soon as its
    /// field is fixed (4d).
    @State private var errors = OnboardingCardEditErrors()
    @State private var triedToSave = false
    @FocusState private var nameFocused: Bool

    init(viewModel: OnboardingV2ViewModel, card: OnboardingCard, isNew: Bool) {
        self.viewModel = viewModel
        self.card = card
        self.isNew = isNew
        _name = State(initialValue: card.name)
        _description = State(initialValue: card.description)
        _names = State(initialValue: card.names)
        _examples = State(initialValue: card.examples)
    }

    private var maxLength: Int { viewModel.rules.nameMaxChars }
    private var hasName: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    nameField
                    descriptionField
                    // Each field says what the AI does with it, because
                    // editing gave no guidance on how to think about a card.
                    OnboardingChipSection(
                        title: "Keywords",
                        chips: names,
                        hint: "Words or names that should always land here: people, places, nicknames only you use.",
                        error: errors.names,
                        onRemove: { chip in names.removeAll { $0 == chip } },
                        onAdd: { names = OnboardingRules.cleanedChips(names + [$0]) }
                    )
                    OnboardingChipSection(
                        title: "What you’ll dump here",
                        chips: examples,
                        hint: "The kinds of notes you’ll save here. They help when a note doesn’t mention a keyword.",
                        onRemove: { chip in examples.removeAll { $0 == chip } },
                        onAdd: { examples = OnboardingRules.cleanedChips(examples + [$0]) }
                    )
                }
                .padding(.horizontal, OnboardingStyle.gutter)
                .padding(.top, 32)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            bottom
        }
        .background(OnboardingStyle.background.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .onAppear {
            if isNew { nameFocused = true }
        }
        .onChange(of: name) { _, newName in
            // The field stops at the limit, so there is no "too long" error.
            if newName.count > maxLength {
                name = String(newName.prefix(maxLength))
            }
            refreshErrors()
        }
        .onChange(of: names) { _, _ in refreshErrors() }
    }

    private var topBar: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .buttonStyle(OnboardingLinkStyle(font: OnboardingStyle.body))
                .frame(width: 60, alignment: .leading)
            Spacer()
            Text(isNew ? "New category" : "Edit category")
                .font(OnboardingStyle.button)
                .foregroundColor(OnboardingStyle.text)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Color.clear.frame(width: 60, height: 1)
        }
        .padding(.horizontal, OnboardingStyle.gutter)
        .padding(.top, 8)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name").onboardingLabel()
            HStack {
                TextField(
                    "",
                    text: $name,
                    prompt: Text("Name it").foregroundColor(OnboardingStyle.placeholder)
                )
                .font(OnboardingStyle.display(22))
                .tracking(22 * -0.02)
                .foregroundColor(OnboardingStyle.text)
                .focused($nameFocused)
                .submitLabel(.done)
                .accessibilityLabel("Name")
                Text("\(name.count) / \(maxLength)")
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundColor(OnboardingStyle.secondary)
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(RoundedRectangle(cornerRadius: 12).fill(OnboardingStyle.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(nameBorder, lineWidth: 1)
            )
            if let error = errors.name {
                Text(error)
                    .onboardingCaption(OnboardingStyle.danger)
                    .lineSpacing(2)
            }
        }
    }

    private var nameBorder: Color {
        if errors.name != nil { return OnboardingStyle.danger }
        return nameFocused ? OnboardingStyle.text : OnboardingStyle.placeholder
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What it’s for").onboardingLabel()
            TextField(
                "",
                text: $description,
                prompt: Text("What goes here? (optional)").foregroundColor(OnboardingStyle.placeholder),
                axis: .vertical
            )
            .font(OnboardingStyle.body)
            .foregroundColor(OnboardingStyle.text)
            .lineSpacing(4)
            .lineLimit(1...6)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 12).fill(OnboardingStyle.surface))
            .accessibilityLabel("What it's for")
            Text("One sentence that tells the AI what belongs here.")
                .onboardingCaption()
                .lineSpacing(3)
        }
    }

    private var bottom: some View {
        VStack(spacing: 24) {
            Button("Save", action: save)
                .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: hasName))
                .disabled(!hasName)
            if !isNew && viewModel.canRemoveCards {
                Button("Remove this category") {
                    viewModel.removeCard(card.id)
                    dismiss()
                }
                .buttonStyle(OnboardingLinkStyle(color: OnboardingStyle.danger, font: OnboardingStyle.captionMedium))
            }
        }
        .padding(.horizontal, OnboardingStyle.gutter)
        .padding(.top, 12)
        .padding(.bottom, 40)
    }

    private func refreshErrors() {
        guard triedToSave else { return }
        let current = viewModel.editErrors(cardId: isNew ? nil : card.id, name: name, names: names)
        // Fixing a field clears its message; new problems wait for Save.
        errors = OnboardingCardEditErrors(
            name: errors.name == nil ? nil : current.name,
            names: errors.names == nil ? nil : current.names
        )
    }

    private func save() {
        triedToSave = true
        if let failed = viewModel.saveCard(
            cardId: isNew ? nil : card.id,
            name: name,
            description: description,
            names: names,
            examples: examples
        ) {
            errors = failed
            return
        }
        dismiss()
    }
}
