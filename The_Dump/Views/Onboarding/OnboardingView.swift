import SwiftUI
import Combine

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = OnboardingViewModel()
    @State private var currentScreen: OnboardingScreen = .startingPoint

    enum OnboardingScreen {
        case startingPoint
        case categories
        case definitions
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            switch currentScreen {
            case .startingPoint:
                OnboardingStartingPointView(
                    viewModel: viewModel,
                    onContinue: handleStartingPointContinue
                )

            case .categories:
                OnboardingCategoriesView(
                    viewModel: viewModel,
                    onBack: { currentScreen = .startingPoint },
                    onContinue: { currentScreen = .definitions }
                )

            case .definitions:
                OnboardingDefinitionsView(
                    viewModel: viewModel,
                    onBack: { currentScreen = .categories },
                    onComplete: { /* AppState handles navigation */ }
                )
            }
        }
    }

    private func handleStartingPointContinue() {
        guard let preset = viewModel.selectedPreset else { return }

        if preset.isCustomOption {
            currentScreen = .categories
        } else {
            Task {
                let success = await viewModel.submitPreset(appState: appState)
                if !success {
                    // Error is shown in the view via viewModel.errorMessage
                }
            }
        }
    }
}
