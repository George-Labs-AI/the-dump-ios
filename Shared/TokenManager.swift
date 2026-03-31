import Foundation

/// Manages Firebase ID token storage in a shared UserDefaults suite (App Group)
/// so the share extension can read the token written by the main app.
struct TokenManager {
    private let defaults: UserDefaults?

    /// Creates a TokenManager backed by the given UserDefaults suite.
    /// - Parameter suiteName: The App Group identifier. Defaults to `SharedConstants.appGroupID`.
    ///   Pass a custom value in tests for isolation.
    init(suiteName: String = SharedConstants.appGroupID) {
        self.defaults = UserDefaults(suiteName: suiteName)
    }

    /// Saves a Firebase ID token with an expiry window.
    /// - Parameters:
    ///   - token: The Firebase ID token string.
    ///   - expiresIn: Seconds until expiry. Defaults to 3500 (100s buffer before Firebase's 3600s).
    func saveToken(_ token: String, expiresIn seconds: TimeInterval = 3500) {
        let expiryDate = Date().addingTimeInterval(seconds)
        defaults?.set(token, forKey: SharedConstants.tokenKey)
        defaults?.set(expiryDate, forKey: SharedConstants.tokenExpiryKey)
    }

    /// Returns the stored token if it exists and hasn't expired, otherwise nil.
    func getToken() -> String? {
        guard let token = defaults?.string(forKey: SharedConstants.tokenKey),
              let expiryDate = defaults?.object(forKey: SharedConstants.tokenExpiryKey) as? Date,
              expiryDate > Date() else {
            return nil
        }
        return token
    }

    /// Removes the stored token and expiry.
    func clearToken() {
        defaults?.removeObject(forKey: SharedConstants.tokenKey)
        defaults?.removeObject(forKey: SharedConstants.tokenExpiryKey)
    }

    /// Whether a valid (non-expired) token is available.
    var isTokenValid: Bool {
        getToken() != nil
    }
}
