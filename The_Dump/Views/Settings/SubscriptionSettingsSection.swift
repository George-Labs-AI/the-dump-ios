import SwiftUI
import Combine

struct SubscriptionSettingsSection: View {
    @ObservedObject var viewModel: SubscriptionViewModel
    @Binding var showPaywall: Bool

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
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                if status.notesPercentage >= 90 {
                                    Image(systemName: "exclamationmark.circle")
                                    Text("Almost full ·")
                                }
                                Text("\(status.notesUsed.formatted()) / \(status.monthlyNoteLimit.formatted())")
                            }
                            .font(.system(size: Theme.fontSizeXS))
                            .foregroundColor(Theme.textSecondary)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Theme.surface2)
                                    .frame(height: 6)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Theme.textPrimary)
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
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                if status.wordsPercentage >= 90 {
                                    Image(systemName: "exclamationmark.circle")
                                    Text("Almost full ·")
                                }
                                Text("\(status.wordsUsed.formatted()) / \(status.monthlyWordLimit.formatted())")
                            }
                            .font(.system(size: Theme.fontSizeXS))
                            .foregroundColor(Theme.textSecondary)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Theme.surface2)
                                    .frame(height: 6)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Theme.textPrimary)
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
                if viewModel.tier == .trial, let trialEnd = viewModel.formattedTrialEnd {
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

            // Upgrade button (free/trial only, hidden while loading to avoid
            // briefly showing upgrade option before real tier is known)
            if viewModel.canUpgrade && !viewModel.isLoading {
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
                    // Bought on the web, so it can only be changed there.
                    Button {
                        if let url = URL(string: "\(SharedConstants.defaultBaseURL)/manage-subscription") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Text("Manage Subscription")
                                .foregroundColor(Theme.accent)
                            Spacer()
                            Text("Manage on web")
                                .font(.system(size: Theme.fontSizeXS))
                                .foregroundColor(Theme.textSecondary)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: Theme.fontSizeXS, weight: .semibold))
                                .foregroundColor(Theme.textTertiary)
                        }
                    }
                    .listRowBackground(Theme.surface)
                }
            }
        } header: {
            Text("Subscription")
                .foregroundColor(Theme.textSecondary)
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
}
