import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var showLogoutConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var showDeletePasswordSheet = false
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
                    SubscriptionSettingsSection(viewModel: appState.subscriptionViewModel)

                    // Categories section
                    Section {
                        NavigationLink("Manage Categories", destination: CategoryManagementView())
                            .foregroundColor(Theme.accent)
                            .listRowBackground(Theme.surface)
                    } header: {
                        Text("Categories")
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    // Session section
                    Section {
                        HStack {
                            Text("Uploads this session")
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text("\(sessionStore.items.count)")
                                .foregroundColor(Theme.textPrimary)
                        }
                        .listRowBackground(Theme.surface)
                        
                        if !sessionStore.items.isEmpty {
                            Button("Clear Session History") {
                                sessionStore.clear()
                            }
                            .foregroundColor(Theme.accent)
                            .listRowBackground(Theme.surface)
                        }
                    } header: {
                        Text("Session")
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    // Actions section
                    Section {
                        Button("Sign Out") {
                            showLogoutConfirmation = true
                        }
                        .foregroundColor(Theme.accent)
                        .listRowBackground(Theme.surface)

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

                        Link(destination: URL(string: "https://thedumpapp.com/privacy")!) {
                            HStack {
                                Text("Privacy Policy")
                                    .foregroundColor(Theme.textPrimary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .listRowBackground(Theme.surface)

                        Link(destination: URL(string: "https://thedumpapp.com/terms")!) {
                            HStack {
                                Text("Terms of Use")
                                    .foregroundColor(Theme.textPrimary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textSecondary)
                            }
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
        .sheet(isPresented: $showDeletePasswordSheet) {
            DeleteAccountSheet()
                .environmentObject(appState)
                .environmentObject(sessionStore)
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
}

private struct DeleteAccountSheet: View {
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
