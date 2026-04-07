import SwiftUI

struct LegalView: View {
    let title: String
    let sections: [(heading: String, body: String)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacingLG) {
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
            ("Last Updated", "June 2025"),
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
        ]
    )

    static let termsOfUse = LegalView(
        title: "Terms of Use",
        sections: [
            ("Last Updated", "June 2025"),
            ("Acceptance of Terms", "By accessing or using The Dump (\"the App\"), provided by George Labs, LLC (\"we,\" \"us\"), you agree to comply with and be bound by these Terms of Service. If you disagree with these Terms, you should not use the App."),
            ("Use of the App", """
                You agree to use the App responsibly and lawfully. You must:

                • Provide accurate information during registration and keep it updated
                • Maintain confidentiality and security of your login credentials
                • Not share your account with others or allow unauthorized access

                You may upload files up to a maximum size of 100MB at a time.
                """),
            ("Prohibited Activities", """
                You may not use the App to:

                • Engage in unlawful or harmful activities
                • Upload or distribute offensive, illegal, or infringing content
                • Attempt to disrupt, damage, or compromise the security or integrity of the App
                • Deliberately overload the App, repeatedly upload identical content, or otherwise maliciously attempt to test or undermine the App's functionality
                """),
            ("Intellectual Property", "The Dump and all related materials, including software, features, and content (excluding your personal data and uploaded content), are owned by George Labs, LLC and protected by intellectual property laws."),
            ("User Content", "You retain ownership of content you upload. By using the App, you grant us the rights necessary to store, process, and display your content solely to provide the App's services.\n\nIf you delete your notes, they are permanently deleted, and we are not responsible for recovering them."),
            ("Beta Service Disclaimer", "The App is currently in beta. We reserve the right to make changes to functionality, payment tiers, and upload limits."),
            ("Termination", "We reserve the right to terminate or suspend your access without notice if you violate these Terms or for reasons deemed necessary to protect the App or its users."),
            ("Disclaimers and Liability", "The App is provided \"as-is\" without warranties of any kind. We are not liable for damages from use or inability to use the App, including data loss or unauthorized access, beyond what applicable law requires."),
            ("Changes to Terms", "We may update these Terms periodically. Significant changes will be communicated via email. Continued use of the App after notification constitutes acceptance of the revised Terms."),
            ("Governing Law", "These Terms are governed by the laws of the United States and the state where George Labs, LLC is registered."),
            ("Contact Us", "For questions regarding these Terms, contact support@georgelabs.ai.")
        ]
    )
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
