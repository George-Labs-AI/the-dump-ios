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
                } else {
                    CategoryRecategorizationTracker.shared.clear()
                }
                // Share token with extension via App Groups
                await self?.syncTokenToSharedStorage(user: user)
            }
        }
    }
    
    /// Writes the current Firebase ID token to shared storage so the share extension can read it.
    /// Called on auth state change and when the app goes to background.
    func syncTokenToSharedStorage(user: User?) async {
        let tokenManager = TokenManager()
        if let user {
            do {
                let token = try await user.getIDToken()
                tokenManager.saveToken(token)
            } catch {
                #if DEBUG
                print("[AppState] Failed to save token to shared storage: \(error)")
                #endif
            }
        } else {
            tokenManager.clearToken()
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

        // Someone who saved their categories but closed the app on the
        // "You're done organizing" or first-note screen goes back there,
        // even though the account now has categories.
        if OnboardingProgressStore(uid: userId).hasFinishedButNotLeft {
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
            if counts.hasAnyCategories {
#if DEBUG
                print("[AppState] Found \(counts.categoryBucketCount) categories on server - skipping onboarding")
#endif
                UserDefaults.standard.set(true, forKey: "onboarding_completed_\(userId)")
                // Onboarded somewhere else (the web, another phone): any
                // half-finished progress on this phone is stale.
                OnboardingProgressStore(uid: userId).clear()
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

    /// Test accounts only (THEDUMP-47): the website deletes this account's
    /// categories and notes, then the phone forgets its onboarding progress
    /// and goes back to the first onboarding screen, still signed in. If the
    /// website call fails, nothing on the phone is cleared.
    func resetOnboarding() async throws {
        guard let userId = currentUser?.uid else { throw APIError.noAuthToken }
        try await NotesService.shared.resetOnboarding()

        Self.forgetOnboarding(uid: userId)
        CategoryRecategorizationTracker.shared.clear()
        await PendingNotesStore.shared.removeAll()
        // Set directly rather than through checkOnboardingStatus(), which
        // would ask the server again: the reset just removed every category,
        // so the answer is already known.
        isCheckingOnboardingStatus = false
        hasCompletedOnboarding = false
    }

    /// Removes what marks onboarding as started or done for one account on
    /// this phone: the saved progress (which would otherwise resume screens
    /// 5 and 6) and the "completed" flag.
    static func forgetOnboarding(
        uid: String,
        store: OnboardingProgressStore? = nil,
        defaults: UserDefaults = .standard
    ) {
        (store ?? OnboardingProgressStore(uid: uid)).clear()
        defaults.removeObject(forKey: "onboarding_completed_\(uid)")
    }

    private func clearLocalData() {
        if let userId = currentUser?.uid {
            Self.forgetOnboarding(uid: userId)
        }
        TokenManager().clearToken()
        isAuthenticated = false
        userEmail = nil
        currentUser = nil
        hasCompletedOnboarding = false
    }

    /// Whether the onboarding is what's on screen, which is always dark
    /// whatever the appearance setting (D-071).
    var isShowingOnboarding: Bool {
        isAuthenticated && !isCheckingOnboardingStatus && !hasCompletedOnboarding
    }

    /// Called when the person leaves the onboarding's last screens.
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
