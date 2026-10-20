import SwiftUI

// Screens 2b (listening back), 3b (building categories) and their failed
// version 2f: an eyebrow, a headline, three steps on a vertical rail that
// tick off as the real calls finish, and a promise line at the bottom.

/// One row on a loading screen's rail.
struct OnboardingRailStep: Identifiable {
    enum State: Equatable {
        case done
        case active
        case pending
        case failed
    }

    let id: Int
    let title: String
    let state: State
    /// Lines revealed under the row ("Heard 'newsletter'").
    var lines: [String] = []
}

struct OnboardingLoadingLayout: View {
    let eyebrow: String
    let headline: String
    let steps: [OnboardingRailStep]
    let footerLabel: String
    let footer: String
    let failure: OnboardingFailure?
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(failure == nil ? eyebrow : "Paused")
                        .onboardingLabel()
                    Text(failure == nil ? headline : "That didn’t go through.")
                        .onboardingHeadline()
                        .accessibilityAddTraits(.isHeader)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(steps) { step in
                            OnboardingRailRow(step: step, isLast: step.id == steps.last?.id)
                        }
                    }
                    .padding(.top, 24)
                }
                .padding(.horizontal, OnboardingStyle.gutter)
                .padding(.top, 48)
            }
            if failure != nil {
                failureFooter
            } else {
                promiseFooter
            }
        }
    }

    private var promiseFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle().fill(OnboardingStyle.hairline).frame(height: 1)
                .padding(.bottom, 16)
            Text(footerLabel).onboardingLabel()
            Text(footer)
                .font(OnboardingStyle.display(22))
                .tracking(OnboardingStyle.displayTracking(22) / 2)
                .foregroundColor(OnboardingStyle.text)
        }
        .padding(.horizontal, OnboardingStyle.gutter)
        .padding(.bottom, 48)
        .accessibilityElement(children: .combine)
    }

    private var failureFooter: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(OnboardingStyle.text)
                Text("What you said is saved. No need to record again.")
                    .onboardingCaption(OnboardingStyle.text)
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: OnboardingStyle.cardRadius).fill(OnboardingStyle.surface))
            Button("Try again", action: onRetry)
                .buttonStyle(OnboardingPrimaryButtonStyle())
        }
        .padding(.horizontal, OnboardingStyle.gutter)
        .padding(.bottom, 40)
    }
}

/// A step on the rail: a circle (ticked, spinning, empty or "!") joined to
/// the next by a thin line.
struct OnboardingRailRow: View {
    let step: OnboardingRailStep
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                marker
                    .frame(width: 24, height: 24)
                if !isLast {
                    Rectangle()
                        .fill(OnboardingStyle.hairline)
                        .frame(width: 1)
                        .frame(minHeight: 24, maxHeight: .infinity)
                }
            }
            .frame(width: 24)

            VStack(alignment: .leading, spacing: 8) {
                Text(step.title)
                    .font(OnboardingStyle.bodyMedium)
                    .foregroundColor(step.state == .pending ? OnboardingStyle.secondary : OnboardingStyle.text)
                    .padding(.top, 2)
                if step.state == .failed {
                    Text("This step didn’t finish. It’s on our side, not yours.")
                        .onboardingCaption()
                }
                ForEach(Array(step.lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .onboardingCaption()
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.bottom, isLast ? 0 : 24)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(accessibilityState)
    }

    @ViewBuilder
    private var marker: some View {
        switch step.state {
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(OnboardingStyle.background)
                .frame(width: 24, height: 24)
                .background(Circle().fill(OnboardingStyle.text))
        case .active:
            ProgressView()
                .progressViewStyle(.circular)
                .tint(OnboardingStyle.text)
                .scaleEffect(0.8)
        case .pending:
            Circle().stroke(OnboardingStyle.hairline, lineWidth: 1.5)
        case .failed:
            Text("!")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(OnboardingStyle.text)
                .frame(width: 24, height: 24)
                .overlay(Circle().stroke(OnboardingStyle.text, lineWidth: 1.5))
        }
    }

    private var accessibilityState: String {
        switch step.state {
        case .done: return "Done"
        case .active: return "In progress"
        case .pending: return "Waiting"
        case .failed: return "Didn't finish"
        }
    }
}

// MARK: - Screen 2b: listening back

struct OnboardingListeningScreen: View {
    @ObservedObject var viewModel: OnboardingV2ViewModel

    var body: some View {
        OnboardingLoadingLayout(
            eyebrow: "Working on it · About 10 sec",
            headline: "Listening back",
            steps: steps,
            footerLabel: "While you wait",
            footer: "From here on, it sorts itself.",
            failure: viewModel.progress.failure,
            onRetry: { Task { await viewModel.retryFailedStep() } }
        )
        .animation(.easeInOut(duration: 0.25), value: viewModel.heardLinesShown)
    }

    private var steps: [OnboardingRailStep] {
        let failed = viewModel.progress.failure?.task
        let transcribe: OnboardingRailStep.State = viewModel.isTranscribeDone ? .done : (failed == .transcribe ? .failed : .active)
        let read: OnboardingRailStep.State
        if viewModel.isReadDone {
            read = viewModel.heardLinesShown >= viewModel.heardPhrases.count ? .done : .active
        } else if failed == .read {
            read = .failed
        } else {
            read = viewModel.isTranscribeDone ? .active : .pending
        }
        let check: OnboardingRailStep.State
        if viewModel.isCheckDone {
            check = .done
        } else if failed == .check {
            check = .failed
        } else {
            check = read == .done ? .active : .pending
        }
        let heard = viewModel.heardPhrases
            .prefix(viewModel.heardLinesShown)
            .map { "Heard ‘\($0)’" }
        return [
            OnboardingRailStep(id: 0, title: "Transcribing what you said", state: transcribe),
            OnboardingRailStep(id: 1, title: "Picking out what you’re juggling", state: read, lines: heard),
            OnboardingRailStep(id: 2, title: "Checking what you might have missed", state: check)
        ]
    }
}

// MARK: - Screen 3b: building categories

struct OnboardingBuildingScreen: View {
    @ObservedObject var viewModel: OnboardingV2ViewModel

    var body: some View {
        OnboardingLoadingLayout(
            eyebrow: "Almost there · About 15 sec",
            headline: "Building your categories",
            steps: steps,
            footerLabel: "While you wait",
            footer: "Talk once. It handles the rest.",
            failure: viewModel.progress.failure,
            onRetry: { Task { await viewModel.retryFailedStep() } }
        )
        .animation(.easeInOut(duration: 0.25), value: viewModel.buildingLinesShown)
    }

    private var steps: [OnboardingRailStep] {
        let failed = viewModel.progress.failure?.task == .draft
        let names: OnboardingRailStep.State
        if viewModel.isBuildingDone {
            names = .done
        } else {
            names = failed ? .failed : .active
        }
        let lines = Array(viewModel.buildingLines.prefix(viewModel.buildingLinesShown))
        return [
            OnboardingRailStep(id: 0, title: "Grouping what you’re juggling", state: .done),
            OnboardingRailStep(id: 1, title: "Finding the names that matter", state: names, lines: lines),
            OnboardingRailStep(id: 2, title: "Drafting your categories", state: viewModel.isBuildingDone ? .done : .pending)
        ]
    }
}
