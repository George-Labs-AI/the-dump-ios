import Foundation

/// Keeps one person's onboarding progress in the App Group defaults, so a
/// killed app resumes at the step it left. Keyed by Firebase uid, so two
/// accounts on one phone never share progress.
struct OnboardingProgressStore {
    private let defaults: UserDefaults?
    private let key: String

    init(uid: String, defaults: UserDefaults? = UserDefaults(suiteName: SharedConstants.appGroupID)) {
        self.defaults = defaults
        self.key = "onboarding_progress_v1_\(uid)"
    }

    func load() -> OnboardingProgress? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(OnboardingProgress.self, from: data)
    }

    func save(_ progress: OnboardingProgress) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        defaults?.set(data, forKey: key)
    }

    func clear() {
        defaults?.removeObject(forKey: key)
    }

    /// True when this person saved their categories but hasn't left
    /// onboarding yet (screens 5 and 6). The account already has categories
    /// then, so the usual "has categories" check would skip straight to the
    /// main app; this keeps them on the screen they were on.
    var hasFinishedButNotLeft: Bool {
        load()?.step.isAfterFinish == true
    }
}
