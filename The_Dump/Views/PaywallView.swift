import SwiftUI

struct PaywallView: View {
    @ObservedObject var viewModel: SubscriptionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.spacingXL) {
                        headerSection
                        featuresSection
                        pricingSection

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.system(size: Theme.fontSizeSM))
                                .foregroundColor(Theme.accent)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, Theme.spacingMD)
                        }

                        actionButtons
                    }
                    .padding(.horizontal, Theme.spacingLG)
                    .padding(.vertical, Theme.spacingXL)
                }
            }
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onChange(of: viewModel.tier) { _, newTier in
                if newTier == .paid {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: Theme.spacingMD) {
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(Theme.accent)

            Text("Unlock Full Access")
                .font(.system(size: Theme.fontSizeXL, weight: .bold))
                .foregroundColor(Theme.textPrimary)

            Text("More notes, more words, more power.")
                .font(.system(size: Theme.fontSizeMD))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Theme.spacingLG)
    }

    private var featuresSection: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Text("")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Free")
                    .font(.system(size: Theme.fontSizeXS, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 70)
                Text("Pro")
                    .font(.system(size: Theme.fontSizeXS, weight: .semibold))
                    .foregroundColor(Theme.accent)
                    .frame(width: 70)
            }
            .padding(.horizontal, Theme.spacingMD)
            .padding(.vertical, Theme.spacingSM)

            Divider().background(Theme.border)

            tierRow(feature: "Notes / month", free: "150", pro: "2,500")
            Divider().background(Theme.border)
            tierRow(feature: "Words / month", free: "10K", pro: "500K")
            Divider().background(Theme.border)
            tierRow(feature: "Voice memos", free: "checkmark", pro: "checkmark")
            Divider().background(Theme.border)
            tierRow(feature: "Photo captures", free: "checkmark", pro: "checkmark")
            Divider().background(Theme.border)
            tierRow(feature: "AI organization", free: "checkmark", pro: "checkmark")
            Divider().background(Theme.border)
            tierRow(feature: "Search", free: "checkmark", pro: "checkmark")
        }
        .background(Theme.surface)
        .cornerRadius(Theme.cornerRadius)
    }

    private func tierRow(feature: String, free: String, pro: String) -> some View {
        HStack {
            Text(feature)
                .font(.system(size: Theme.fontSizeSM))
                .foregroundColor(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            tierCell(value: free, highlight: false)
                .frame(width: 70)
            tierCell(value: pro, highlight: true)
                .frame(width: 70)
        }
        .padding(.horizontal, Theme.spacingMD)
        .padding(.vertical, Theme.spacingSM)
    }

    @ViewBuilder
    private func tierCell(value: String, highlight: Bool) -> some View {
        if value == "checkmark" {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(highlight ? Theme.accent : Theme.textSecondary)
        } else {
            Text(value)
                .font(.system(size: Theme.fontSizeSM, weight: highlight ? .semibold : .regular))
                .foregroundColor(highlight ? Theme.accent : Theme.textSecondary)
        }
    }

    private var pricingSection: some View {
        VStack(spacing: Theme.spacingSM) {
            Text(viewModel.formattedPrice)
                .font(.system(size: Theme.fontSizeXXL, weight: .bold))
                .foregroundColor(Theme.textPrimary)

            Text("per month")
                .font(.system(size: Theme.fontSizeSM))
                .foregroundColor(Theme.textSecondary)

            if let status = viewModel.usageStatus, viewModel.canUpgrade {
                Text("\(status.notesUsed) of \(status.monthlyNoteLimit) free notes used this month")
                    .font(.system(size: Theme.fontSizeXS))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.top, Theme.spacingXS)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: Theme.spacingMD) {
            Button {
                Task { await viewModel.purchase() }
            } label: {
                Group {
                    if viewModel.isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.textPrimary))
                    } else {
                        Text("Subscribe")
                    }
                }
                .font(.system(size: Theme.fontSizeMD, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.spacingMD)
                .background(Theme.accent)
                .cornerRadius(Theme.cornerRadius)
            }
            .disabled(viewModel.isPurchasing)

            Button {
                Task { await viewModel.restore() }
            } label: {
                Text("Restore Purchases")
                    .font(.system(size: Theme.fontSizeSM, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
            }
            .disabled(viewModel.isPurchasing)

            // Legal links (Apple review requirement)
            HStack(spacing: Theme.spacingMD) {
                Link("Terms of Use", destination: URL(string: "https://thedumpapp.com/terms")!)
                Text("·").foregroundColor(Theme.textQuaternary)
                Link("Privacy Policy", destination: URL(string: "https://thedumpapp.com/privacy")!)
            }
            .font(.system(size: Theme.fontSizeXS))
            .foregroundColor(Theme.textTertiary)
        }
    }
}

#Preview {
    let vm = SubscriptionViewModel()
    vm.usageStatus = UsageStatusResponse(
        subscriptionTier: .free,
        notesUsed: 120,
        monthlyNoteLimit: 150,
        wordsUsed: 7500,
        monthlyWordLimit: 10000,
        usagePercentage: 80,
        isBlocked: false,
        blockedReason: nil,
        trialEndsAt: nil,
        resetsAt: "2026-03-01T00:00:00Z",
        subscriptionProvider: nil,
        subscriptionStatus: nil,
        subscriptionExpiresAt: nil
    )
    return PaywallView(viewModel: vm)
}
