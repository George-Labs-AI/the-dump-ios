import Foundation

enum SubscriptionTier: String, Codable {
    case free
    case trial
    case paid
    case preApproved = "pre_approved"
}

enum SubscriptionProvider: String, Codable {
    case apple
    case stripe
}

enum SubscriptionStatus: String, Codable {
    case active
    case billingRetry = "billing_retry"
    case expired
    case revoked
    case refunded
}

struct UsageStatusResponse: Codable {
    let subscriptionTier: SubscriptionTier
    let notesUsed: Int
    let monthlyNoteLimit: Int
    let wordsUsed: Int
    let monthlyWordLimit: Int
    let usagePercentage: Double
    let isBlocked: Bool
    let blockedReason: String?
    let trialEndsAt: String?
    let resetsAt: String
    let subscriptionProvider: SubscriptionProvider?
    let subscriptionStatus: SubscriptionStatus?
    let subscriptionExpiresAt: String?

    var notesPercentage: Double {
        guard monthlyNoteLimit > 0 else { return 0 }
        return Double(notesUsed) / Double(monthlyNoteLimit) * 100
    }

    var wordsPercentage: Double {
        guard monthlyWordLimit > 0 else { return 0 }
        return Double(wordsUsed) / Double(monthlyWordLimit) * 100
    }

    enum CodingKeys: String, CodingKey {
        case subscriptionTier = "subscription_tier"
        case notesUsed = "notes_used"
        case monthlyNoteLimit = "monthly_note_limit"
        case wordsUsed = "words_used"
        case monthlyWordLimit = "monthly_word_limit"
        case usagePercentage = "usage_percentage"
        case isBlocked = "is_blocked"
        case blockedReason = "blocked_reason"
        case trialEndsAt = "trial_ends_at"
        case resetsAt = "resets_at"
        case subscriptionProvider = "subscription_provider"
        case subscriptionStatus = "subscription_status"
        case subscriptionExpiresAt = "subscription_expires_at"
    }
}

struct VerifyPurchaseResponse: Codable {
    let success: Bool
    let subscriptionTier: SubscriptionTier

    enum CodingKeys: String, CodingKey {
        case success
        case subscriptionTier = "subscription_tier"
    }
}
