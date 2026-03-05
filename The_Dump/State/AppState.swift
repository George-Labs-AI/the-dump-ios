import Foundation
import FirebaseAuth
import Combine

@MainActor
// obervableobject means that other files can access these variables if @environmentobject is also set to receive the info
class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var userEmail: String?
    @Published var currentUser: User?
    @Published var hasCompletedOnboarding = false
    @Published var isCheckingOnboardingStatus = false

    let subscriptionViewModel = SubscriptionViewModel()

    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    var idToken: String? {
        get async {
            guard let user = currentUser else { return nil }
            do {
                return try await user.getIDToken()
            } catch {
                print("Failed to get ID token: \(error)")
                return nil
            }
        }
    }
    
    func listenToAuthChanges() {
        // this below code basically tells the app to listen to firebase and if the auth state changes, to listen up and make the necessary changes
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            // below code therefore runs anytime the login state changes
            // Task creates an async environment where we are allowed to update UI based on network events
            Task { @MainActor in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                self?.userEmail = user?.email
                // Load subscription status when user signs in
                if user != nil {
                    await self?.subscriptionViewModel.loadStatus()
                }
            }
        }
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
    }

    func checkOnboardingStatus() {
        guard let userId = currentUser?.uid else {
            hasCompletedOnboarding = false
            isCheckingOnboardingStatus = false
            return
        }

        // Fast path: check local cache first (instant)
        if UserDefaults.standard.bool(forKey: "onboarding_completed_\(userId)") {
            hasCompletedOnboarding = true
            isCheckingOnboardingStatus = false
            return
        }

        // Slow path: check server for existing categories
        // This handles: new device, reinstall, or user who completed onboarding elsewhere
        isCheckingOnboardingStatus = true
        Task {
            await checkServerForCategories(userId: userId)
        }
    }

    private func checkServerForCategories(userId: String) async {
        defer { isCheckingOnboardingStatus = false }
        do {
            let counts = try await NotesService.shared.fetchCounts()

            // If user has any categories on server, they've completed onboarding
            if !counts.categories.isEmpty {
#if DEBUG
                print("[AppState] Found \(counts.categories.count) categories on server - skipping onboarding")
#endif
                UserDefaults.standard.set(true, forKey: "onboarding_completed_\(userId)")
                hasCompletedOnboarding = true
            } else {
#if DEBUG
                print("[AppState] No categories on server - showing onboarding")
#endif
                hasCompletedOnboarding = false
            }
        } catch {
#if DEBUG
            print("[AppState] Failed to check categories: \(error) - showing onboarding")
#endif
            // On error, default to showing onboarding (safe fallback)
            hasCompletedOnboarding = false
        }
    }

    func deleteAccount(password: String) async throws {
        // Step 1: Re-authenticate (Firebase requires recent auth to delete)
        try await AuthService.shared.reauthenticate(password: password)

        // Step 2: Delete all user data on backend (while token is still valid)
        try await NotesService.shared.deleteAccount()

        // Step 3: Delete the Firebase Auth account
        try await AuthService.shared.deleteFirebaseAccount()

        // Step 4: Clean up local state
        clearLocalData()
    }

    private func clearLocalData() {
        if let userId = currentUser?.uid {
            UserDefaults.standard.removeObject(forKey: "onboarding_completed_\(userId)")
        }
        isAuthenticated = false
        userEmail = nil
        currentUser = nil
        hasCompletedOnboarding = false
    }

    func markOnboardingComplete() {
        guard let userId = currentUser?.uid else { return }
        UserDefaults.standard.set(true, forKey: "onboarding_completed_\(userId)")
        hasCompletedOnboarding = true
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}