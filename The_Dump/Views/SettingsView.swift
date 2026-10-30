import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var showLogoutConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var showDeletePasswordSheet = false
    @State private var showPaywall = false
    @State private var showsResetOnboarding = false
    @State private var showResetOnboardingConfirmation = false
    @State private var isResettingOnboarding = false
    @State private var resetOnboardingErrorMessage = ""
    @State private var showResetOnboardingError = false
    @AppStorage("appearance") private var appearance: AppAppearance = .system

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                
                List {
                    // Account section
                    Section {
                        HStack {
                            Text("Email")
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text(appState.userEmail ?? "—")
                                .foregroundColor(Theme.textPrimary)
                        }
                        .listRowBackground(Theme.surface)

                        ExportDataRow()
                            .listRowBackground(Theme.surface)
                    } header: {
                        Text("Account")
                            .foregroundColor(Theme.textSecondary)
                    }

                    // Appearance section
                    Section {
                        Picker("Appearance", selection: $appearance) {
                            ForEach(AppAppearance.allCases, id: \.self) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Theme.surface)
                    } header: {
                        Text("Appearance")
                            .foregroundColor(Theme.textSecondary)
                    }

                    // Subscription section
                    SubscriptionSettingsSection(viewModel: appState.subscriptionViewModel, showPaywall: $showPaywall)

                    // Categories section. The main way in is now the Edit
                    // button on Browse (THEDUMP-123); this row stays so people
                    // who learned to look here still find it.
                    Section {
                        NavigationLink("Manage Categories", destination: ManageCategoriesView())
                            .foregroundColor(Theme.accent)
                            .listRowBackground(Theme.surface)
                    } header: {
                        Text("Categories")
                            .foregroundColor(Theme.textSecondary)
                    }

                    // AI assistants section (THEDUMP-135)
                    Section {
                        NavigationLink("Connect to Claude", destination: ConnectToClaudeView())
                            .foregroundColor(Theme.accent)
                            .listRowBackground(Theme.surface)
                    } header: {
                        Text("AI assistants")
                            .foregroundColor(Theme.textSecondary)
                    } footer: {
                        Text("Save chats here and ask Claude about your notes.")
                            .foregroundColor(Theme.textSecondary)
                    }

                    // Actions section
                    Section {
                        Button("Sign Out") {
                            showLogoutConfirmation = true
                        }
                        .foregroundColor(Theme.accent)
                        .listRowBackground(Theme.surface)

                        // Only test accounts on the website's reset list see this.
                        if showsResetOnboarding {
                            Button {
                                showResetOnboardingConfirmation = true
                            } label: {
                                HStack {
                                    Text("Reset onboarding (test accounts)")
                                    Spacer()
                                    if isResettingOnboarding {
                                        ProgressView()
                                    }
                                }
                            }
                            .foregroundColor(.red)
                            .disabled(isResettingOnboarding)
                            .listRowBackground(Theme.surface)
                        }

                        Button("Delete Account") {
                            showDeleteConfirmation = true
                        }
                        .foregroundColor(.red)
                        .listRowBackground(Theme.surface)
                    }

                    // App info
                    Section {
                        HStack {
                            Text("Version")
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text(appVersion)
                                .foregroundColor(Theme.textPrimary)
                        }
                        .listRowBackground(Theme.surface)

                        // The support page lists the support email address and the FAQ.
                        Button {
                            if let url = URL(string: "\(SharedConstants.defaultBaseURL)/support") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack {
                                Text("Contact support")
                                    .foregroundColor(Theme.textPrimary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: Theme.fontSizeXS, weight: .semibold))
                                    .foregroundColor(Theme.textTertiary)
                            }
                        }
                        .listRowBackground(Theme.surface)

                        NavigationLink {
                            LegalView.privacyPolicy
                        } label: {
                            Text("Privacy Policy")
                                .foregroundColor(Theme.textPrimary)
                        }
                        .listRowBackground(Theme.surface)

                        NavigationLink {
                            LegalView.termsOfUse
                        } label: {
                            Text("Terms of Use")
                                .foregroundColor(Theme.textPrimary)
                        }
                        .listRowBackground(Theme.surface)

                        NavigationLink {
                            LegalView.serviceRules
                        } label: {
                            Text("Service Rules")
                                .foregroundColor(Theme.textPrimary)
                        }
                        .listRowBackground(Theme.surface)
                    } header: {
                        Text("About")
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Theme.textPrimary)
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .task {
            let counts = try? await NotesService.shared.fetchCounts()
            showsResetOnboarding = counts?.isOnboardingResetAllowed ?? false
        }
        .confirmationDialog(
            "Sign Out",
            isPresented: $showLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Delete Account?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Continue", role: .destructive) {
                showDeletePasswordSheet = true
            }
        } message: {
            Text("This will permanently delete your account and all your data. This action cannot be undone.")
        }
        .alert("Reset Onboarding?", isPresented: $showResetOnboardingConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                Task { await resetOnboarding() }
            }
        } message: {
            Text("This deletes all of this account's categories and notes, then starts the onboarding again from the first screen. You stay signed in.")
        }
        .alert("Reset Failed", isPresented: $showResetOnboardingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resetOnboardingErrorMessage)
        }
        .sheet(isPresented: $showDeletePasswordSheet) {
            DeleteAccountSheet()
                .environmentObject(appState)
                .environmentObject(sessionStore)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(viewModel: appState.subscriptionViewModel)
        }
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    private func signOut() {
        do {
            sessionStore.clear()
            try appState.signOut()
            dismiss()
        } catch {
            print("Sign out error: \(error)")
        }
    }

    private func resetOnboarding() async {
        isResettingOnboarding = true
        defer { isResettingOnboarding = false }

        do {
            try await appState.resetOnboarding()
            sessionStore.clear()
            dismiss()
        } catch {
            resetOnboardingErrorMessage = Self.resetOnboardingErrorMessage(for: error)
            showResetOnboardingError = true
        }
    }

    /// 404 means the website doesn't have this account on its reset list.
    static func resetOnboardingErrorMessage(for error: Error) -> String {
        if case APIError.notFound = error {
            return "This account can't be reset."
        }
        return "Couldn't reset. Try again."
    }
}

/// Also opened from the onboarding's menu.
struct DeleteAccountSheet: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var password = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: Theme.spacingLG) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                        .padding(.top, Theme.spacingXL)

                    Text("Enter your password to confirm account deletion")
                        .font(.system(size: Theme.fontSizeMD))
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.spacingLG)

                    SecureField("Password", text: $password)
                        .textFieldStyle(DumpPasswordFieldStyle())
                        .textContentType(.password)
                        .padding(.horizontal, Theme.spacingLG)
                        .disabled(isDeleting)

                    if isDeleting {
                        ProgressView("Deleting account...")
                            .foregroundColor(Theme.textSecondary)
                    } else {
                        Button(role: .destructive) {
                            Task { await performDeletion() }
                        } label: {
                            Text("Delete My Account")
                                .font(.system(size: Theme.fontSizeMD, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.spacingSMPlus)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .disabled(password.isEmpty)
                        .padding(.horizontal, Theme.spacingLG)
                    }

                    Spacer()
                }
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.textPrimary)
                        .disabled(isDeleting)
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .interactiveDismissDisabled(isDeleting)
        }
        .alert("Deletion Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unexpected error occurred. Please try again.")
        }
    }

    private func performDeletion() async {
        isDeleting = true
        defer { isDeleting = false }

        do {
            sessionStore.clear()
            try await appState.deleteAccount(password: password)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
        .environmentObject(SessionStore())
}
