import SwiftUI

struct LegalView: View {
    let title: String
    let sections: [(heading: String, body: String)]
    let topLinks: [(title: String, destination: URL)]
    let footerLinks: [(title: String, destination: URL)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingLG) {
                if !topLinks.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.spacingSM) {
                        ForEach(topLinks.indices, id: \.self) { index in
                            Link(topLinks[index].title, destination: topLinks[index].destination)
                                .font(.system(size: Theme.fontSizeSM, weight: .medium))
                                .foregroundColor(Theme.accent)
                        }
                    }
                }

                ForEach(sections.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: Theme.spacingSM) {
                        Text(sections[index].heading)
                            .font(.system(size: Theme.fontSizeMD, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)

                        Text(sections[index].body)
                            .font(.system(size: Theme.fontSizeSM))
                            .foregroundColor(Theme.textSecondary)
                    }
                }

                if !footerLinks.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.spacingSM) {
                        ForEach(footerLinks.indices, id: \.self) { index in
                            Link(footerLinks[index].title, destination: footerLinks[index].destination)
                                .font(.system(size: Theme.fontSizeSM, weight: .medium))
                                .foregroundColor(Theme.accent)
                        }
                    }
                    .padding(.top, Theme.spacingSM)
                }
            }
            .padding(Theme.spacingLG)
        }
        .background(Theme.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    static let privacyPolicy = LegalView(
        title: "Privacy Policy",
        sections: [
            ("Last Updated", "April 2026"),
            ("Introduction", "George Labs, LLC (operating as \"The Dump\") commits to protecting user privacy through this policy describing data collection, usage, and user rights."),
            ("Information We Collect", """
                Personal Information: First name, last name, email address.

                User Content: Files you upload, including associated file names, timestamps, transcripts, and file types, plus user-generated notes and categories.

                Usage Information: Frequency of app use, login dates and times, interactions within the app.
                """),
            ("Purpose of Data Collection", "Data serves exclusively to provide and improve app functionality. We do not sell, rent, or market your personal data to any third parties."),
            ("Third-Party Services", "Trusted service providers process data solely for essential app functionality, with no sharing for marketing purposes."),
            ("Data Security", "Protection includes encrypting data in transit (using HTTPS) and at rest using the security measures provided by our cloud service provider."),
            ("Data Retention", "Data persists while accounts remain active. You can delete or export your data at any time via account settings or by contacting support@georgelabs.ai."),
            ("User Rights", "We comply with GDPR and CCPA/CPRA, allowing you to access, correct, delete, export, or withdraw consent through account settings or by contacting support@georgelabs.ai."),
            ("Children's Privacy", "The Dump does not knowingly collect data from users under 13. Please notify us immediately if you believe a child's data has been inadvertently collected."),
            ("Policy Changes", "Updates occur periodically with email notification. Continued use implies acceptance."),
            ("Contact", "Questions? Reach us at support@georgelabs.ai.")
        ],
        topLinks: [
            ("Open Online Privacy Policy", privacyPolicyURL)
        ],
        footerLinks: []
    )

    static let termsOfUse = LegalView(
        title: "Terms of Use",
        sections: [
            ("Last Updated", "April 2026"),
            ("Apple Standard Terms", "The Dump for iOS uses Apple's Standard Licensed Application End User License Agreement for the app license provided through the App Store."),
            ("What This Means", "Apple's standard Terms of Use govern the license to download and use the iOS app on Apple devices. The full agreement is published by Apple and can be opened from the link below."),
            ("Separate Service Rules", "Subscriptions, usage limits, account safety rules, and service operations for The Dump are described separately in the in-app Service Rules page.")
        ],
        topLinks: [],
        footerLinks: [
            ("Open Apple's Standard Terms of Use", appleStandardTermsURL)
        ]
    )

    static let serviceRules = LegalView(
        title: "Service Rules",
        sections: [
            ("Last Updated", "April 2026"),
            ("Accounts", "Use accurate account information, keep your login credentials secure, and do not share your account or allow unauthorized access."),
            ("Subscriptions & Limits", "Free and paid plans may have different feature access, note limits, upload limits, and monthly usage caps. We may update plan details, pricing, or limits as the service evolves."),
            ("Acceptable Use", """
                Do not use The Dump to:

                • Upload illegal, abusive, or infringing content
                • Attempt to disrupt, probe, or compromise the security of the app or backend
                • Circumvent plan limits, automate abusive usage, or interfere with other users
                """),
            ("Content & Processing", "You keep ownership of the content you upload. By using The Dump, you allow us to store, process, and analyze that content as needed to provide features like syncing, transcription, AI-powered organization, and search."),
            ("Restrictions & Suspension", "We may limit features, restrict access, or suspend accounts when required for subscription enforcement, abuse prevention, security, legal compliance, or protection of the service and its users."),
            ("Deletion", "You can delete your account through the app's settings. Content deleted by you or removed with account deletion may persist temporarily in backups or operational systems before being fully purged, as described in the Privacy Policy."),
            ("Changes", "We may update these service rules as the app changes. Continued use of The Dump after changes take effect means the updated rules apply."),
            ("Contact", "Questions about these service rules can be sent to support@georgelabs.ai.")
        ],
        topLinks: [],
        footerLinks: []
    )

    private static let privacyPolicyURL = URL(string: "https://thedump.ai/privacy")!
    private static let appleStandardTermsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

#Preview("Privacy Policy") {
    NavigationStack {
        LegalView.privacyPolicy
    }
}

#Preview("Terms of Use") {
    NavigationStack {
        LegalView.termsOfUse
    }
}

#Preview("Service Rules") {
    NavigationStack {
        LegalView.serviceRules
    }
}
