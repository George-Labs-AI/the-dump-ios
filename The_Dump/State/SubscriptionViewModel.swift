import Foundation
import StoreKit
import Combine

@MainActor
class SubscriptionViewModel: ObservableObject {
    @Published var usageStatus: UsageStatusResponse?
    @Published var product: Product?
    @Published var isLoading = false
    @Published var isPurchasing = false
    @Published var errorMessage: String?

    var tier: SubscriptionTier {
        usageStatus?.subscriptionTier ?? .free
    }

    var isBlocked: Bool {
        usageStatus?.isBlocked ?? false
    }

    var canUpgrade: Bool {
        tier == .free || tier == .trial
    }

    var formattedPrice: String {
        product?.displayPrice ?? "$29.99"
    }

    var usagePercentage: Double {
        usageStatus?.usagePercentage ?? 0
    }

    var notesPercentage: Double {
        usageStatus?.notesPercentage ?? 0
    }

    var wordsPercentage: Double {
        usageStatus?.wordsPercentage ?? 0
    }

    /// Human-readable string for the limiting factor shown in banners
    var limitingFactorLabel: String {
        guard let status = usageStatus else { return "" }
        if status.notesPercentage >= status.wordsPercentage {
            return "\(status.notesUsed.formatted()) of \(status.monthlyNoteLimit.formatted()) notes used"
        } else {
            return "\(status.wordsUsed.formatted()) of \(status.monthlyWordLimit.formatted()) words used"
        }
    }

    var formattedResetDate: String? {
        guard let resetsAt = usageStatus?.resetsAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: resetsAt) ?? ISO8601DateFormatter().date(from: resetsAt) else {
            return nil
        }
        let display = DateFormatter()
        display.dateStyle = .medium
        return display.string(from: date)
    }

    var formattedTrialEnd: String? {
        guard let trialEndsAt = usageStatus?.trialEndsAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: trialEndsAt) ?? ISO8601DateFormatter().date(from: trialEndsAt) else {
            return nil
        }
        let display = DateFormatter()
        display.dateStyle = .medium
        return display.string(from: date)
    }

    var subscriptionProvider: SubscriptionProvider? {
        usageStatus?.subscriptionProvider
    }

    var isBillingRetry: Bool {
        usageStatus?.subscriptionStatus == .billingRetry
    }

    var formattedExpiryDate: String? {
        guard let expiresAt = usageStatus?.subscriptionExpiresAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: expiresAt) ?? ISO8601DateFormatter().date(from: expiresAt) else {
            return nil
        }
        let display = DateFormatter()
        display.dateStyle = .medium
        return display.string(from: date)
    }

    func loadStatus() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            usageStatus = try await SubscriptionService.shared.fetchUsageStatus()
        } catch {
#if DEBUG
            print("[SubscriptionVM] Failed to load usage status: \(error)")
#endif
            errorMessage = error.localizedDescription
        }

        await StoreKitService.shared.loadProducts()
        product = StoreKitService.shared.product
    }

    func purchase() async {
        // Check backend tier first (spec Section 3)
        do {
            let status = try await SubscriptionService.shared.fetchUsageStatus()
            usageStatus = status
            if status.subscriptionTier == .paid || status.subscriptionTier == .preApproved {
                errorMessage = "You already have an active subscription."
                return
            }
        } catch {
            errorMessage = "Could not verify subscription status. Please try again."
            return
        }

        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            let (transaction, jwsRepresentation) = try await StoreKitService.shared.purchase()

            // Verify with backend
            let verifyResponse = try await SubscriptionService.shared.verifyPurchase(
                signedTransaction: jwsRepresentation
            )

            if verifyResponse.success {
                await transaction.finish()
                // Refresh status from backend
                usageStatus = try? await SubscriptionService.shared.fetchUsageStatus()
            }
        } catch let error as StoreKitError where error == .userCancelled {
            // User cancelled — not an error
            return
        } catch let error as APIError {
            switch error {
            case .conflict:
                errorMessage = "This purchase is already linked to another account, or you have an active web subscription."
            default:
                errorMessage = error.localizedDescription
            }
        } catch let error as StoreKitError {
            if case .purchasePending = error {
                errorMessage = "Your purchase is pending approval. You'll get access once it's confirmed."
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        guard let (transaction, jwsRepresentation) = await StoreKitService.shared.checkEntitlement() else {
            errorMessage = "No active subscription found to restore."
            return
        }

        do {
            let verifyResponse = try await SubscriptionService.shared.verifyPurchase(
                signedTransaction: jwsRepresentation
            )

            if verifyResponse.success {
                await transaction.finish()
                usageStatus = try? await SubscriptionService.shared.fetchUsageStatus()
            }
        } catch let error as APIError {
            switch error {
            case .conflict:
                errorMessage = "This purchase is already linked to another account, or you have an active web subscription."
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Called from transaction listener when a background transaction update arrives
    func handleTransactionUpdate(_ transaction: Transaction, jwsRepresentation: String) async {
        if transaction.revocationDate != nil {
            // Subscription was revoked — refresh status from backend
            usageStatus = try? await SubscriptionService.shared.fetchUsageStatus()
        } else {
            // Renewal or new entitlement — verify and refresh
            _ = try? await SubscriptionService.shared.verifyPurchase(
                signedTransaction: jwsRepresentation
            )
            await transaction.finish()
            usageStatus = try? await SubscriptionService.shared.fetchUsageStatus()
        }
    }
}

// Equatable conformance for StoreKitError to allow pattern matching
extension StoreKitError: Equatable {
    static func == (lhs: StoreKitError, rhs: StoreKitError) -> Bool {
        switch (lhs, rhs) {
        case (.productNotFound, .productNotFound),
             (.userCancelled, .userCancelled),
             (.purchasePending, .purchasePending),
             (.unknown, .unknown):
            return true
        case (.unexpectedProduct(let a), .unexpectedProduct(let b)):
            return a == b
        default:
            return false
        }
    }
}
