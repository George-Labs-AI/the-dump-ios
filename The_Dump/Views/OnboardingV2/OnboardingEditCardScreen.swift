import SwiftUI

// MARK: - Screen 4b: edit a category (and 4c/4d: add one)

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
    @State private var error: String?
    @State private var triedToSave = false

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

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    nameField
                    descriptionField
                    OnboardingChipSection(
                        title: "Names that mean this",
                        chips: names,
                        onRemove: { chip in names.removeAll { $0 == chip } },
                        onAdd: { names = OnboardingRules.cleanedChips(names + [$0]) }
                    )
                    OnboardingChipSection(
                        title: "What you’ll dump here",
                        chips: examples,
                        onRemove: { chip in examples.removeAll { $0 == chip } },
                        onAdd: { examples = OnboardingRules.cleanedChips(examples + [$0]) }
                    )
                }
                .padding(.horizontal, OnboardingStyle.gutter)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            bottom
        }
        .background(OnboardingStyle.background.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .onChange(of: name) { _, _ in refreshError() }
        .onChange(of: names) { _, _ in refreshError() }
    }

    private var topBar: some View {
        ZStack {
            Text(isNew ? "Add a category" : "Edit category")
                .font(OnboardingStyle.bodyMedium)
                .foregroundColor(OnboardingStyle.text)
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(OnboardingLinkStyle(color: OnboardingStyle.text, font: OnboardingStyle.body))
                Spacer()
            }
        }
        .padding(.horizontal, OnboardingStyle.gutter)
        .frame(height: 56)
        .overlay(alignment: .bottom) {
            Rectangle().fill(OnboardingStyle.hairline).frame(height: 1)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Name").onboardingLabel()
                Spacer()
                Text("\(name.trimmingCharacters(in: .whitespacesAndNewlines).count) / \(maxLength)")
                    .onboardingCaption(name.count > maxLength ? OnboardingStyle.danger : OnboardingStyle.secondary)
                    .monospacedDigit()
            }
            TextField("", text: $name, prompt: Text("Kitchen reno").foregroundColor(OnboardingStyle.placeholder))
                .font(OnboardingStyle.body)
                .foregroundColor(OnboardingStyle.text)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(RoundedRectangle(cornerRadius: OnboardingStyle.cardRadius).fill(OnboardingStyle.surface))
                .overlay(
                    RoundedRectangle(cornerRadius: OnboardingStyle.cardRadius)
                        .stroke(nameHasError ? OnboardingStyle.danger : OnboardingStyle.hairline, lineWidth: 1)
                )
                .accessibilityLabel("Name")
            if let error, triedToSave || !name.isEmpty {
                Text(error).onboardingCaption(OnboardingStyle.danger)
            }
        }
    }

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What it’s for").onboardingLabel()
            TextField(
                "",
                text: $description,
                prompt: Text("Redoing the kitchen at the house on Maple St.").foregroundColor(OnboardingStyle.placeholder),
                axis: .vertical
            )
            .font(OnboardingStyle.body)
            .foregroundColor(OnboardingStyle.text)
            .lineLimit(2...5)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: OnboardingStyle.cardRadius).fill(OnboardingStyle.surface))
            .overlay(
                RoundedRectangle(cornerRadius: OnboardingStyle.cardRadius)
                    .stroke(OnboardingStyle.hairline, lineWidth: 1)
            )
            .accessibilityLabel("What it's for")
        }
    }

    private var bottom: some View {
        VStack(spacing: 16) {
            Button("Save", action: save)
                .buttonStyle(OnboardingPrimaryButtonStyle())
            if !isNew && viewModel.canRemoveCards {
                Button("Remove this category") {
                    viewModel.removeCard(card.id)
                    dismiss()
                }
                .buttonStyle(OnboardingLinkStyle(color: OnboardingStyle.danger, font: OnboardingStyle.body))
            }
        }
        .padding(.horizontal, OnboardingStyle.gutter)
        .padding(.top, 12)
        .padding(.bottom, 24)
    }

    private var nameHasError: Bool {
        guard let error else { return false }
        return (triedToSave || !name.isEmpty) && !error.hasPrefix("Add at least one name")
    }

    private func refreshError() {
        guard triedToSave || !name.isEmpty else { return }
        error = viewModel.editError(cardId: isNew ? nil : card.id, name: name, names: names)
    }

    private func save() {
        triedToSave = true
        if let message = viewModel.saveCard(
            cardId: isNew ? nil : card.id,
            name: name,
            description: description,
            names: names,
            examples: examples
        ) {
            error = message
            return
        }
        dismiss()
    }
}
