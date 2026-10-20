import SwiftUI

/// The voice onboarding, shown to a signed-in person with no categories
/// (and, after Finish, until they leave its last screen). One container with
/// a step per screen, so resuming after the app was closed is just showing
/// the saved step. Always dark (D-071).
struct OnboardingV2View: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: OnboardingV2ViewModel

    init(uid: String) {
        _viewModel = StateObject(wrappedValue: OnboardingV2ViewModel(uid: uid))
    }

    var body: some View {
        ZStack {
            OnboardingStyle.background.ignoresSafeArea()
            screen
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.step)
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .task {
            await viewModel.resume()
        }
    }

    @ViewBuilder
    private var screen: some View {
        switch viewModel.step {
        case .promise:
            OnboardingPromiseScreen(viewModel: viewModel)
        case .record:
            OnboardingRecordScreen(viewModel: viewModel)
        case .listening:
            OnboardingListeningScreen(viewModel: viewModel)
        case .questions:
            OnboardingQuestionsScreen(viewModel: viewModel)
        case .building:
            OnboardingBuildingScreen(viewModel: viewModel)
        case .review:
            OnboardingReviewScreen(viewModel: viewModel)
        case .done, .first:
            OnboardingFirstNoteScreen(viewModel: viewModel, onLeave: leave)
        }
    }

    /// Go to my Dump, the capture bar after the first note, or the Claude
    /// link: onboarding is over, and the main app opens on the Dump tab.
    private func leave() {
        viewModel.leave()
        appState.markOnboardingComplete()
    }
}

// MARK: - Screen 1: the promise

struct OnboardingPromiseScreen: View {
    @ObservedObject var viewModel: OnboardingV2ViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("The Dump")
                .onboardingLabel(OnboardingStyle.text)
                .padding(.top, 16)

            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 16) {
                Text("You will never organize a note again.")
                    .onboardingHeadline(52, lineHeight: 50)
                    .accessibilityAddTraits(.isHeader)
                Text("Create your categories to begin.")
                    .onboardingBody()
            }

            Spacer(minLength: 24)

            VStack(spacing: 16) {
                Text("Takes about 3 minutes")
                    .onboardingLabel()
                Button("Begin") {
                    viewModel.begin()
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())
            }
        }
        .padding(.horizontal, OnboardingStyle.gutter)
        .padding(.bottom, 40)
    }
}
