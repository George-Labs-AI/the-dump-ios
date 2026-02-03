import Foundation
import FirebaseAuth
import Combine

@MainActor
// obervableobject means that other files can access these variables if @environmentobject is also set to receive the info
class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var userEmail: String?
    @Published var currentUser: User?
    
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
            }
        }
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
}
