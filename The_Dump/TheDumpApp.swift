import SwiftUI
import FirebaseCore
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

enum AppAppearance: String, CaseIterable {
    case system
    case light
    case dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

@main
struct TheDumpApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState()
    @AppStorage("appearance") private var appearance: AppAppearance = .system
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(appearance.colorScheme)
                .task {
                    // Start listening for StoreKit transaction updates (renewals, revocations)
                    StoreKitService.shared.listenForTransactions { transaction, jwsRepresentation in
                        await appState.subscriptionViewModel.handleTransactionUpdate(transaction, jwsRepresentation: jwsRepresentation)
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background {
                        // Refresh the shared token so the share extension has a fresh one
                        Task {
                            await appState.syncTokenToSharedStorage(user: Auth.auth().currentUser)
                        }
                    }
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.isAuthenticated {
                if appState.isCheckingOnboardingStatus {
                    // Brief loading state while checking server for categories
                    ZStack {
                        Theme.background.ignoresSafeArea()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.textPrimary))
                    }
                } else if appState.hasCompletedOnboarding {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            } else {
                AuthView()
            }
        }
        .onAppear {
            appState.listenToAuthChanges()
        }
        .onChange(of: appState.currentUser) { _, newUser in
            if newUser != nil {
                appState.checkOnboardingStatus()
            }
        }
    }
}
