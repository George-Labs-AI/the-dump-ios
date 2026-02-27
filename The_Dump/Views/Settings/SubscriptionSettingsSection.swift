import SwiftUI

struct SubscriptionSettingsSection: View {
    @ObservedObject var viewModel: SubscriptionViewModel
    @State private var showPaywall = false

    var body: some View {
        Section {
            // Current tier
            HStack {
                Text("Plan")
                    .foregroundColor(Theme.textSecondary)
                Spacer()
                tierBadge
            }
            .listRowBackground(Theme.surface)

            // Usage
            if let status = viewModel.usageStatus {
                VStack(alignment: .leading, spacing: Theme.spacingMD) {
                    // Notes usage
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Notes")
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text("\(status.notesUsed.formatted()) / \(status.monthlyNoteLimit.formatted())")
                                .font(.system(size: Theme.fontSizeXS))
                                .foregroundColor(Theme.textSecondary)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Theme.surface2)
                                    .frame(height: 6)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(barColor(for: status.notesPercentage))
                                    .frame(width: geo.size.width * min(status.notesPercentage / 100, 1.0), height: 6)
                            }
                        }
                        .frame(height: 6)
                    }

                    // Words usage
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Words")
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text("\(status.wordsUsed.formatted()) / \(status.monthlyWordLimit.formatted())")
                                .font(.system(size: Theme.fontSizeXS))
                                .foregroundColor(Theme.textSecondary)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Theme.surface2)
                                    .frame(height: 6)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(barColor(for: status.wordsPercentage))
                                    .frame(width: geo.size.width * min(status.wordsPercentage / 100, 1.0), height: 6)
                            }
                        }
                        .frame(height: 6)
                    }
                }
                .listRowBackground(Theme.surface)

                // Reset date
                if let resetDate = viewModel.formattedResetDate {
                    HStack {
                        Text("Resets")
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text(resetDate)
                            .foregroundColor(Theme.textPrimary)
                    }
                    .listRowBackground(Theme.surface)
                }

                // Trial end date
                if let trialEnd = viewModel.formattedTrialEnd {
                    HStack {
                        Text("Trial ends")
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text(trialEnd)
                            .foregroundColor(Theme.accent)
                    }
                    .listRowBackground(Theme.surface)
                }

                // Subscription expiry date
                if let expiryDate = viewModel.formattedExpiryDate {
                    HStack {
                        Text("Expires")
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text(expiryDate)
                            .foregroundColor(Theme.textPrimary)
                    }
                    .listRowBackground(Theme.surface)
                }

                // Billing retry warning
                if viewModel.isBillingRetry {
                    HStack(spacing: Theme.spacingSM) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Theme.warning)
                        Text("Payment issue — update your payment method in Settings > Apple ID")
                            .font(.system(size: Theme.fontSizeXS))
                            .foregroundColor(Theme.warning)
                    }
                    .listRowBackground(Theme.warning.opacity(0.1))
                }
            }

            // Upgrade button (free/trial only)
            if viewModel.canUpgrade {
                Button("Upgrade to Pro") {
                    showPaywall = true
                }
                .foregroundColor(Theme.accent)
                .listRowBackground(Theme.surface)
            }

            // Manage subscription (provider-aware)
            if viewModel.tier == .paid || viewModel.tier == .preApproved {
                if viewModel.subscriptionProvider == .apple {
                    Button("Manage Subscription") {
                        if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .foregroundColor(Theme.accent)
                    .listRowBackground(Theme.surface)
                } else if viewModel.subscriptionProvider == .stripe {
                    HStack {
                        Text("Manage Subscription")
                            .foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text("Manage on web")
                            .font(.system(size: Theme.fontSizeXS))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .listRowBackground(Theme.surface)
                }
            }
        } header: {
            Text("Subscription")
                .foregroundColor(Theme.textSecondary)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(viewModel: viewModel)
        }
    }

    private var tierBadge: some View {
        Text(tierLabel)
            .font(.system(size: Theme.fontSizeXS, weight: .semibold))
            .foregroundColor(tierColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tierColor.opacity(0.15))
            .cornerRadius(6)
    }

    private var tierLabel: String {
        switch viewModel.tier {
        case .free: return "Free"
        case .trial: return "Trial"
        case .paid: return "Pro"
        case .preApproved: return "Pro"
        }
    }

    private var tierColor: Color {
        switch viewModel.tier {
        case .free: return Theme.textSecondary
        case .trial: return Theme.warning
        case .paid, .preApproved: return Theme.success
        }
    }

    private func barColor(for percentage: Double) -> Color {
        if percentage >= 90 { return Theme.accent }
        if percentage >= 70 { return Theme.warning }
        return Theme.success
    }
}
