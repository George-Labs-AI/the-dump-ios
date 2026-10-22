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
        case .explainer:
            OnboardingExplainerScreen(viewModel: viewModel)
        case .record:
            OnboardingRecordScreen(viewModel: viewModel)
        case .listening:
            OnboardingListeningScreen(viewModel: viewModel)
        case .names:
            OnboardingNamesScreen(viewModel: viewModel)
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

    /// Go to The Dump, the capture bar after the first note, or the Claude
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
                Text("Takes about 5 minutes")
                    .onboardingLabel()
                Button("Begin") {
                    viewModel.begin()
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())
                Button("Set up my categories myself") {
                    viewModel.setUpMyself()
                }
                .buttonStyle(OnboardingLinkStyle(font: .system(size: 15)))
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, OnboardingStyle.gutter)
        .padding(.bottom, 40)
    }
}

// MARK: - Screen 1b: how sorting works

/// Before anyone starts talking: sorting runs on clues, and keywords (the
/// names only they would use) help most. The example is fixed copy, not
/// their data.
struct OnboardingExplainerScreen: View {
    @ObservedObject var viewModel: OnboardingV2ViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("How sorting works")
                        .onboardingLabel(OnboardingStyle.text)
                    Text("Every note is sorted by its clues.")
                        .onboardingHeadline(34, lineHeight: 36)
                        .accessibilityAddTraits(.isHeader)
                    Text("When you dump something, the AI reads it and puts it in the category it fits best. Keywords help the most: the names only you would connect to one part of your life.")
                        .onboardingBody()
                    exampleCard
                        .padding(.top, 8)
                    Text("You can add sub-categories later, too.")
                        .font(.system(size: 14))
                        .foregroundColor(OnboardingStyle.secondary)
                        .padding(.top, 4)
                }
                .padding(.horizontal, OnboardingStyle.gutter)
                .padding(.top, 40)
                .padding(.bottom, 24)
            }

            VStack(spacing: 16) {
                Text("Next: what you’re juggling")
                    .onboardingLabel()
                Button("Continue") {
                    viewModel.continueFromExplainer()
                }
                .buttonStyle(OnboardingPrimaryButtonStyle())
            }
            .padding(.horizontal, OnboardingStyle.gutter)
            .padding(.bottom, 40)
        }
    }

    private var exampleCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("You dump").onboardingLabel()
                Text("“Ask the designer for Pocketly’s new logo by Friday.”")
                    .onboardingBody(OnboardingStyle.text)
            }
            Rectangle()
                .fill(OnboardingStyle.hairline)
                .frame(height: 1)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Sorted into My app")
                        .onboardingLabel(OnboardingStyle.text)
                    Spacer(minLength: 8)
                    Text("Pocketly")
                        .font(OnboardingStyle.captionMedium)
                        .foregroundColor(OnboardingStyle.background)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(RoundedRectangle(cornerRadius: 6).fill(OnboardingStyle.text))
                }
                Text("Nothing in the note says “app”. It landed there because you told it Pocketly is a keyword for that category.")
                    .font(.system(size: 14))
                    .foregroundColor(OnboardingStyle.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onboardingCard()
        .accessibilityElement(children: .combine)
    }
}
