import SwiftUI

/// The "•••" menu at the top right of every onboarding screen
/// (THEDUMP-132). Settings can't be reached until onboarding is over, so
/// this carries the account actions someone may need before then: see which
/// account they're on, sign out to switch, contact support, or delete the
/// account. Test accounts also get "Start over".
struct OnboardingMenu: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: OnboardingV2ViewModel

    @State private var showsStartOver = false
    @State private var showSignOutConfirmation = false
    @State private var showStartOverConfirmation = false
    @State private var isStartingOver = false
    @State private var startOverErrorMessage = ""
    @State private var showStartOverError = false
    @State private var showDeleteConfirmation = false
    @State private var showDeletePasswordSheet = false
    @Environment(\.openURL) private var openURL

    static let supportAddress = "support@georgelabs.ai"

    var body: some View {
        Menu {
            if let email = appState.userEmail {
                Text("Signed in as \(email)")
                Divider()
            }
            Button {
                showSignOutConfirmation = true
            } label: {
                Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
            }
            Button {
                if let url = URL(string: "mailto:\(Self.supportAddress)") {
                    openURL(url)
                }
            } label: {
                Label("Contact support", systemImage: "envelope")
                Text(Self.supportAddress)
            }
            // Only test accounts on the website's reset list see this, as
            // in Settings.
            if showsStartOver {
                Divider()
                Button(role: .destructive) {
                    showStartOverConfirmation = true
                } label: {
                    Label("Start over (test accounts)", systemImage: "arrow.counterclockwise")
                }
            }
            Divider()
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete account", systemImage: "trash")
            }
        } label: {
            Group {
                if isStartingOver {
                    ProgressView().tint(OnboardingStyle.text)
                } else {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(OnboardingStyle.text)
                }
            }
            .frame(width: 44, height: 44, alignment: .trailing)
            .contentShape(Rectangle())
        }
        .disabled(isStartingOver)
        .accessibilityLabel("Account")
        .task {
            let counts = try? await NotesService.shared.fetchCounts()
            showsStartOver = counts?.isOnboardingResetAllowed ?? false
        }
        .confirmationDialog(
            "Sign out?",
            isPresented: $showSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive) {
                signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your progress is saved. Sign back in to pick up where you left off.")
        }
        .alert("Start over?", isPresented: $showStartOverConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Start over", role: .destructive) {
                Task { await startOver() }
            }
        } message: {
            Text("This deletes all of this account's categories and notes, then starts the onboarding again from the first screen. You stay signed in.")
        }
        .alert("Couldn't start over", isPresented: $showStartOverError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(startOverErrorMessage)
        }
        .alert("Delete Account?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Continue", role: .destructive) {
                showDeletePasswordSheet = true
            }
        } message: {
            Text("This will permanently delete your account and all your data. This action cannot be undone.")
        }
        .sheet(isPresented: $showDeletePasswordSheet) {
            DeleteAccountSheet()
                .environmentObject(appState)
                .environmentObject(SessionStore())
        }
    }

    /// The saved progress stays on the phone under this account, so signing
    /// back in resumes at the same screen. A recording in progress is
    /// thrown away when its screen disappears (D-020).
    private func signOut() {
        do {
            try appState.signOut()
        } catch {
            #if DEBUG
            print("[OnboardingMenu] Sign out error: \(error)")
            #endif
        }
    }

    /// The same reset as Settings' "Reset onboarding". Once it succeeds,
    /// this onboarding stops saving, so a reply still on its way can't write
    /// the old progress back before the fresh onboarding replaces it.
    private func startOver() async {
        isStartingOver = true
        defer { isStartingOver = false }

        do {
            try await appState.resetOnboarding()
            viewModel.leave()
        } catch {
            startOverErrorMessage = SettingsView.resetOnboardingErrorMessage(for: error)
            showStartOverError = true
        }
    }
}
