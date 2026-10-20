import SwiftUI

// MARK: - Screen 4: here's what we heard

struct OnboardingReviewScreen: View {
    @ObservedObject var viewModel: OnboardingV2ViewModel
    /// The card being edited on 4b; a new card when `isAdding`.
    @State private var editing: OnboardingCard?
    @State private var isAdding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingProgressBar(filled: 3)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Here’s what we heard.")
                            .onboardingHeadline()
                            .accessibilityAddTraits(.isHeader)
                        Spacer(minLength: 12)
                        Text("\(viewModel.approvedCount) of \(viewModel.progress.cards.count) done")
                            .onboardingLabel()
                            .fixedSize()
                    }
                    VStack(spacing: 12) {
                        ForEach(viewModel.progress.cards) { card in
                            if viewModel.openCardId == card.id {
                                OnboardingOpenCard(
                                    viewModel: viewModel,
                                    card: card,
                                    onEdit: { editing = card }
                                )
                            } else {
                                OnboardingCollapsedCard(
                                    card: card,
                                    onOpen: { viewModel.openCard(card.id) },
                                    onEdit: { editing = card }
                                )
                            }
                        }
                        if viewModel.canAddCards {
                            addCategoryRow
                        }
                    }
                }
                .padding(.horizontal, OnboardingStyle.gutter)
                .padding(.top, 40)
                .padding(.bottom, 24)
            }

            VStack(spacing: 12) {
                if let error = viewModel.finishError {
                    Text(error)
                        .onboardingCaption(OnboardingStyle.text)
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
            }
            .padding(.horizontal, OnboardingStyle.gutter)
            .padding(.bottom, 40)
        }
        .sheet(item: $editing) { card in
            OnboardingEditCardScreen(viewModel: viewModel, card: card, isNew: false)
        }
        .sheet(isPresented: $isAdding) {
            OnboardingEditCardScreen(viewModel: viewModel, card: OnboardingCard(name: ""), isNew: true)
        }
    }

    private var addCategoryRow: some View {
        Button {
            isAdding = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                Text("Add a category")
                    .font(OnboardingStyle.bodyMedium)
                Spacer()
            }
            .foregroundColor(OnboardingStyle.secondary)
            .padding(.horizontal, OnboardingStyle.cardPadding)
            .frame(height: 56)
            .overlay(
                RoundedRectangle(cornerRadius: OnboardingStyle.cardRadius)
                    .stroke(OnboardingStyle.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A collapsed card: approved ("Newsletter · 3 names" with a check), missing
/// names ("!" and "Add a name"), or waiting ("Review").
struct OnboardingCollapsedCard: View {
    let card: OnboardingCard
    let onOpen: () -> Void
    let onEdit: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                marker.frame(width: 22, height: 22)
                Text(title)
                    .font(OnboardingStyle.bodyMedium)
                    .foregroundColor(OnboardingStyle.text)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if card.approved {
                    Button("Edit", action: onEdit)
                        .buttonStyle(OnboardingLinkStyle())
                } else {
                    Text(card.canApprove ? "Review" : "Add a name")
                        .onboardingCaption()
                }
            }
            .padding(.horizontal, OnboardingStyle.cardPadding)
            .frame(minHeight: 56)
            .background(RoundedRectangle(cornerRadius: OnboardingStyle.cardRadius).fill(OnboardingStyle.surface))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var title: String {
        guard card.approved else { return card.name }
        let count = card.names.count
        return "\(card.name) · \(count) \(count == 1 ? "name" : "names")"
    }

    @ViewBuilder
    private var marker: some View {
        if card.approved {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(OnboardingStyle.background)
                .frame(width: 22, height: 22)
                .background(Circle().fill(OnboardingStyle.text))
        } else if !card.canApprove || card.errorMessage != nil {
            Text("!")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(OnboardingStyle.text)
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(OnboardingStyle.text, lineWidth: 1.5))
        } else {
            Circle().stroke(OnboardingStyle.secondary, lineWidth: 1.5)
        }
    }
}

/// The open card: title with Edit, description, the two chip lists with
/// "+ Add", and "Looks right".
struct OnboardingOpenCard: View {
    @ObservedObject var viewModel: OnboardingV2ViewModel
    let card: OnboardingCard
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(card.name)
                        .font(OnboardingStyle.display(22))
                        .tracking(OnboardingStyle.displayTracking(22) / 2)
                        .foregroundColor(OnboardingStyle.text)
                    Spacer()
                    Button("Edit", action: onEdit)
                        .buttonStyle(OnboardingLinkStyle(color: OnboardingStyle.text))
                }
                if !card.description.isEmpty {
                    Text(card.description).onboardingCaption()
                }
                if let error = card.errorMessage {
                    Text(error)
                        .onboardingCaption(OnboardingStyle.danger)
                }
            }
            OnboardingChipSection(
                title: "Names that mean this",
                chips: card.names,
                onAdd: { viewModel.addChip($0, to: .names, cardId: card.id) }
            )
            OnboardingChipSection(
                title: "What you’ll dump here",
                chips: card.examples,
                onAdd: { viewModel.addChip($0, to: .examples, cardId: card.id) }
            )
            if !card.canApprove {
                Text("Add at least one name so notes can find this category.")
                    .onboardingCaption()
            }
            Button("Looks right") {
                withAnimation { viewModel.approveCard(card.id) }
            }
            .buttonStyle(OnboardingPrimaryButtonStyle(isEnabled: card.canApprove && card.errorMessage == nil))
            .disabled(!card.canApprove || card.errorMessage != nil)
        }
        .padding(OnboardingStyle.cardPadding)
        .background(RoundedRectangle(cornerRadius: OnboardingStyle.cardRadius).fill(OnboardingStyle.background))
        .overlay(
            RoundedRectangle(cornerRadius: OnboardingStyle.cardRadius)
                .stroke(OnboardingStyle.text, lineWidth: 1)
        )
    }
}

/// A label and a wrapping row of chips, ending in "+ Add", which turns into
/// a small text field.
struct OnboardingChipSection: View {
    let title: String
    let chips: [String]
    var onRemove: ((String) -> Void)?
    let onAdd: (String) -> Void
    @State private var isAdding = false
    @State private var newChip = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).onboardingLabel()
            OnboardingFlowLayout(spacing: 8) {
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
                        .frame(minWidth: 90)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(Capsule().stroke(OnboardingStyle.text, lineWidth: 1))
                        .onAppear { isFocused = true }
                        .onChange(of: isFocused) { _, focused in
                            if !focused { commit() }
                        }
                } else {
                    Button {
                        isAdding = true
                    } label: {
                        Text("+ Add")
                            .font(OnboardingStyle.caption)
                            .foregroundColor(OnboardingStyle.secondary)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .overlay(Capsule().stroke(OnboardingStyle.hairline, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add to \(title)")
                }
            }
        }
    }

    private func chipView(_ chip: String) -> some View {
        HStack(spacing: 6) {
            Text(chip)
                .font(OnboardingStyle.caption)
                .foregroundColor(OnboardingStyle.text)
            if let onRemove {
                Button {
                    onRemove(chip)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(OnboardingStyle.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(chip)")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(Capsule().fill(OnboardingStyle.surface))
        .overlay(Capsule().stroke(OnboardingStyle.hairline, lineWidth: 1))
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
