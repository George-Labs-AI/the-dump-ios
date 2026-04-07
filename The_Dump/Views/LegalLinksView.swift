import SwiftUI

struct LegalLinksView: View {
    @State private var showingLegalPage: LegalPage?

    var body: some View {
        HStack(spacing: Theme.spacingMD) {
            Button("Terms of Use") { showingLegalPage = .terms }
            Text("·")
                .foregroundColor(Theme.textQuaternary)
            Button("Privacy Policy") { showingLegalPage = .privacy }
        }
        .font(.system(size: Theme.fontSizeXS))
        .foregroundColor(Theme.textTertiary)
        .sheet(item: $showingLegalPage) { page in
            NavigationStack {
                page.view
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showingLegalPage = nil }
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .toolbarBackground(Theme.background, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
        }
    }

    private enum LegalPage: Identifiable {
        case terms
        case privacy

        var id: Self { self }

        var view: LegalView {
            switch self {
            case .terms:
                return LegalView.termsOfUse
            case .privacy:
                return LegalView.privacyPolicy
            }
        }
    }
}

#Preview {
    LegalLinksView()
        .padding()
        .background(Theme.background)
}
