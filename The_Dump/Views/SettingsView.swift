import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var sessionStore: SessionStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var showLogoutConfirmation = false
    
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
                        .listRowBackground(Theme.darkGray)
                    } header: {
                        Text("Account")
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
                        .listRowBackground(Theme.darkGray)
                        
                        if !sessionStore.items.isEmpty {
                            Button("Clear Session History") {
                                sessionStore.clear()
                            }
                            .foregroundColor(Theme.accent)
                            .listRowBackground(Theme.darkGray)
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
                        .listRowBackground(Theme.darkGray)
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
                        .listRowBackground(Theme.darkGray)
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

#Preview {
    SettingsView()
        .environmentObject(AppState())
        .environmentObject(SessionStore())
}
