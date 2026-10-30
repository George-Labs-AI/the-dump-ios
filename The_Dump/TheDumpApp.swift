import SwiftUI
import FirebaseCore
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        DesignFonts.register()
        return true
    }
}

@main
struct TheDumpApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState()
    @StateObject private var recategorizationTracker = CategoryRecategorizationTracker.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(recategorizationTracker)
                // Dark-only for now: the design system is drawn dark, and light
                // mode comes back later (THEDUMP-143). Info.plist also sets
                // UIUserInterfaceStyle = Dark so system sheets and alerts match.
                .preferredColorScheme(.dark)
                .task {
                    recategorizationTracker.bootstrap()
                    recategorizationTracker.setPollingEnabled(scenePhase == .active)
                    // Start listening for StoreKit transaction updates (renewals, revocations)
                    StoreKitService.shared.listenForTransactions { transaction, jwsRepresentation in
                        await appState.subscriptionViewModel.handleTransactionUpdate(transaction, jwsRepresentation: jwsRepresentation)
                    }
                    // Drop pending-note records past the 24h contract TTL
                    // (and acknowledged terminal ones) on launch.
                    await PendingNotesStore.shared.prune()
                    // Start status polling for any pending records that
                    // survived relaunch (foreground only).
                    NoteStatusService.shared.handleScenePhase(scenePhase)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    recategorizationTracker.setPollingEnabled(newPhase == .active)
                    NoteStatusService.shared.handleScenePhase(newPhase)
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
                } else if let uid = appState.currentUser?.uid {
                    OnboardingV2View(uid: uid)
                        .id("\(uid)#\(appState.onboardingResetCount)")
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
