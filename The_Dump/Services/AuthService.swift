import Foundation
import FirebaseAuth

enum AuthError: LocalizedError {
    case signInFailed(underlying: Error)
    case signUpFailed(underlying: Error)
    case passwordResetFailed(underlying: Error)
    case invalidCredentials
    case networkError
    case unknownError

    var errorDescription: String? {
        switch self {
        case .signInFailed(let error):
            return parseFirebaseError(error)
        case .signUpFailed(let error):
            return parseFirebaseError(error)
        case .passwordResetFailed(let error):
            return parseFirebaseError(error)
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError:
            return "Network error. Please check your connection."
        case .unknownError:
            return "An unknown error occurred"
        }
    }

    private func parseFirebaseError(_ error: Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain else {
            return error.localizedDescription
        }

        switch AuthErrorCode(rawValue: nsError.code) {
        case .wrongPassword, .invalidCredential:
            return "Invalid email or password"
        case .invalidEmail:
            return "Invalid email address"
        case .userNotFound:
            return "No account found with this email"
        case .userDisabled:
            return "This account has been disabled"
        case .networkError:
            return "Network error. Please check your connection."
        case .tooManyRequests:
            return "Too many attempts. Please try again later."
        case .emailAlreadyInUse:
            return "An account with this email already exists"
        case .weakPassword:
            return "Password must be at least 6 characters"
        default:
            return error.localizedDescription
        }
    }
}

class AuthService {
    static let shared = AuthService()
    
    private init() {}
    
    func signIn(email: String, password: String) async throws {
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            throw AuthError.signInFailed(underlying: error)
        }
    }

    func signUp(email: String, password: String) async throws {
        do {
            try await Auth.auth().createUser(withEmail: email, password: password)
        } catch {
            throw AuthError.signUpFailed(underlying: error)
        }
    }

    func sendPasswordReset(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            throw AuthError.passwordResetFailed(underlying: error)
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    func getIDToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw APIError.noAuthToken
        }
        return try await user.getIDToken()
    }
    
    var currentUserEmail: String? {
        Auth.auth().currentUser?.email
    }
    
    var isSignedIn: Bool {
        Auth.auth().currentUser != nil
    }
}
