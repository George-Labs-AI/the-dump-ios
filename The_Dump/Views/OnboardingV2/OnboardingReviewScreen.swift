import SwiftUI

// MARK: - Screen 4: here's what we heard (and 4m, setting up by hand)

struct OnboardingReviewScreen: View {
    @ObservedObject var viewModel: OnboardingV2ViewModel
    /// The card being edited on 4b.
    @State private var editing: OnboardingCard?
    /// 4c: a new, blank card.
    @State private var isAdding = false

    private var isManual: Bool { viewModel.isManualSetup }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingBackBar(isShown: viewModel.canGoBack, action: viewModel.goBack)
            if !isManual {
                OnboardingProgressBar(filled: 3)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .bottom) {
                        Text(isManual ? "Your categories." : "Here’s what we heard.")
                            .onboardingHeadline()
                            .frame(maxWidth: 240, alignment: .leading)
                            .accessibilityAddTraits(.isHeader)
                        Spacer(minLength: 12)
                        Text(countLabel)
                            .onboardingLabel()
                            .fixedSize()
                            .padding(.bottom, 6)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 12)

                    // What the AI sorts with, so people know what to check
                    // or fill in (Emily found editing gave no guidance).
                    Text(isManual
                         ? "Add one for each part of your life you’ll dump notes about. Give each a short description and the keywords that should always land there, like a nickname for a place or a person’s name."
                         : "Every note you dump is checked against each category’s description and keywords. Add any name that should always land in a category, even one only you would know.")
                        .font(.system(size: 15))
                        .foregroundColor(OnboardingStyle.secondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 24)

                    VStack(spacing: 8) {
                        ForEach(viewModel.progress.cards) { card in
                            if viewModel.openCardId == card.id {
                                OnboardingOpenCard(viewModel: viewModel, card: card, onEdit: { editing = card })
                            } else {
                                OnboardingCollapsedCard(card: card) {
                                    withAnimation(.easeInOut(duration: 0.2)) { viewModel.openCard(card.id) }
                                }
                            }
                        }
                        if viewModel.canAddCards {
                            addCategoryRow
                        }
                        Text("Need finer folders? You can add sub-categories later.")
                            .onboardingCaption()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, OnboardingStyle.gutter)
            }

            VStack(spacing: 12) {
                if let error = viewModel.finishError {
                    Text(error)
                        .onboardingCaption(OnboardingStyle.danger)
                        .multilineTextAlignment(.center)
                }
                Button {
                    Task { await viewModel.finish() }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isFinishing {
                            ProgressView().tint(OnboardingStyle.background)
                        }
                        Text(viewModel.finishLabel)
                    }
                }
                .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: viewModel.canFinish))
                .disabled(!viewModel.canFinish || viewModel.isFinishing)
                if isManual {
                    Button("Rather talk it through? Let the AI draft them") {
                        viewModel.letAIDraft()
                    }
                    .buttonStyle(OnboardingLinkStyle())
                    .disabled(viewModel.isFinishing)
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, OnboardingStyle.gutter)
            .padding(.top, 24)
            .padding(.bottom, isManual ? 32 : 48)
        }
        .fullScreenCover(item: $editing) { card in
            OnboardingEditCardScreen(viewModel: viewModel, card: card, isNew: false)
        }
        .fullScreenCover(isPresented: $isAdding) {
            OnboardingEditCardScreen(viewModel: viewModel, card: OnboardingCard(name: ""), isNew: true)
        }
    }

    /// "2 of 5 done", or "1 added" when setting up by hand (every card made
    /// by hand is approved when it's saved).
    private var countLabel: String {
        let count = viewModel.progress.cards.count
        return isManual ? "\(count) added" : "\(viewModel.approvedCount) of \(count) done"
    }

    private var addCategoryRow: some View {
        Button {
            isAdding = true
        } label: {
            HStack(spacing: 12) {
                Text("+")
                    .font(.system(size: 18))
                    .frame(width: 16)
                Text("Add a category")
                    .font(OnboardingStyle.body)
                Spacer()
            }
            .foregroundColor(OnboardingStyle.secondary)
            .padding(.horizontal, 16)
            .frame(height: 52)
            .overlay(
                RoundedRectangle(cornerRadius: OnboardingStyle.cardRadius)
                    .strokeBorder(OnboardingStyle.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A closed card, 52 tall: approved (grey, a check, "3 keywords"), missing
/// keywords ("!" and "Add a keyword"), or not looked at yet ("Review").
/// Tapping it opens it.
struct OnboardingCollapsedCard: View {
    let card: OnboardingCard
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                marker.frame(width: 16, height: 16)
                Text(card.name)
                    .font(OnboardingStyle.body)
                    .foregroundColor(card.approved || needsAttention ? OnboardingStyle.text : OnboardingStyle.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                trailing
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: OnboardingStyle.cardRadius)
                    .fill(card.approved ? OnboardingStyle.surface : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OnboardingStyle.cardRadius)
                    .strokeBorder(card.approved ? Color.clear : OnboardingStyle.hairline, lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens this category")
    }

    private var needsAttention: Bool { !card.canApprove || card.errorMessage != nil }

    @ViewBuilder
    private var trailing: some View {
        if card.approved {
            let count = card.names.count
            Text(count == 1 ? "1 keyword" : "\(count) keywords")
                .onboardingCaption()
                .monospacedDigit()
        } else if needsAttention {
            Text(card.canApprove ? "Fix the name" : "Add a keyword")
                .font(OnboardingStyle.captionMedium)
                .foregroundColor(OnboardingStyle.text)
        } else {
            Text("Review").onboardingCaption()
        }
    }

    @ViewBuilder
    private var marker: some View {
        if card.approved {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(OnboardingStyle.text)
        } else if needsAttention {
            Text("!")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(OnboardingStyle.text)
                .frame(width: 16, height: 16)
                .overlay(Circle().strokeBorder(OnboardingStyle.text, lineWidth: 1.5))
        } else {
            Circle().strokeBorder(OnboardingStyle.placeholder, lineWidth: 1.5)
        }
    }
}

/// The open card: name and Edit, what it's for, the two chip lists with
/// "+ Add", and "Looks right".
struct OnboardingOpenCard: View {
    @ObservedObject var viewModel: OnboardingV2ViewModel
    let card: OnboardingCard
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(card.name).onboardingTitle()
                Spacer()
                Button("Edit", action: onEdit)
                    .buttonStyle(OnboardingLinkStyle())
            }
            if !card.description.isEmpty {
                Text(card.description)
                    .onboardingCaption()
                    .lineSpacing(3)
            }
            if let error = card.errorMessage {
                Text(error)
                    .onboardingCaption(OnboardingStyle.danger)
                    .lineSpacing(2)
            }
            OnboardingChipSection(
                title: "Keywords",
                chips: card.names,
                error: card.canApprove ? nil : OnboardingRules.missingKeywordMessage,
                onAdd: { viewModel.addChip($0, to: .names, cardId: card.id) }
            )
            OnboardingChipSection(
                title: "What you’ll dump here",
                chips: card.examples,
                onAdd: { viewModel.addChip($0, to: .examples, cardId: card.id) }
            )
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { viewModel.approveCard(card.id) }
            } label: {
                Text("Looks right")
                    .font(OnboardingStyle.bodyMedium)
                    .foregroundColor(canApprove ? OnboardingStyle.background : OnboardingStyle.placeholder)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Capsule().fill(canApprove ? OnboardingStyle.text : OnboardingStyle.hairline))
            }
            .buttonStyle(.plain)
            .disabled(!canApprove)
        }
        .padding(OnboardingStyle.cardPadding)
        .overlay(
            RoundedRectangle(cornerRadius: OnboardingStyle.cardRadius)
                .strokeBorder(OnboardingStyle.placeholder, lineWidth: 1)
        )
    }

    /// A card refused at Finish for its name has to be edited first.
    private var canApprove: Bool { card.canApprove && card.errorMessage == nil }
}

/// A label and a wrapping row of chips ending in "+ Add", which becomes a
/// small text field. On 4b each chip has an × to remove it.
struct OnboardingChipSection: View {
    let title: String
    let chips: [String]
    /// A line under the chips saying what the AI does with them (4b).
    var hint: String?
    var error: String?
    var onRemove: ((String) -> Void)?
    let onAdd: (String) -> Void
    @State private var isAdding = false
    @State private var newChip = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).onboardingLabel()
            OnboardingFlowLayout(spacing: onRemove == nil ? 6 : 8) {
                ForEach(chips, id: \.self) { chip in
                    chipView(chip)
                }
                if isAdding {
                    TextField("", text: $newChip)
                        .font(OnboardingStyle.caption)
                        .foregroundColor(OnboardingStyle.text)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit(commit)
                        .fixedSize()
                        .frame(minWidth: 80, alignment: .leading)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 12)
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(OnboardingStyle.text, lineWidth: 1))
                        .onAppear { isFocused = true }
                        .onChange(of: isFocused) { _, focused in
                            if !focused { commit() }
                        }
                        .accessibilityLabel("New entry for \(title)")
                } else {
                    Button {
                        isAdding = true
                    } label: {
                        Text("+ Add")
                            .font(OnboardingStyle.caption)
                            .foregroundColor(OnboardingStyle.secondary)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(OnboardingStyle.placeholder, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add to \(title)")
                }
            }
            if let hint {
                Text(hint)
                    .onboardingCaption()
                    .lineSpacing(3)
            }
            if let error {
                Text(error)
                    .onboardingCaption(OnboardingStyle.danger)
                    .lineSpacing(2)
            }
        }
    }

    private func chipView(_ chip: String) -> some View {
        HStack(spacing: 4) {
            Text(chip)
                .font(OnboardingStyle.caption)
                .foregroundColor(OnboardingStyle.text)
            if let onRemove {
                Button {
                    onRemove(chip)
                } label: {
                    Text("×")
                        .font(OnboardingStyle.caption)
                        .foregroundColor(OnboardingStyle.text)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(chip)")
            }
        }
        .padding(.vertical, 6)
        .padding(.leading, 12)
        .padding(.trailing, onRemove == nil ? 12 : 10)
        .background(RoundedRectangle(cornerRadius: 8).fill(OnboardingStyle.hairline))
    }

    private func commit() {
        let trimmed = newChip.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            onAdd(trimmed)
        }
        newChip = ""
        isAdding = false
    }
}

/// Lays chips out left to right, wrapping onto new lines.
struct OnboardingFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(width: bounds.width, subviews: subviews)
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row(y: current.y + current.height + spacing)
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty {
            rows.append(current)
        }
        return rows
    }
}
