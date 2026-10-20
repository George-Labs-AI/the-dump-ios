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
    let footer: String
    let failure: OnboardingFailure?
    /// The line on the failed screen saying nothing needs redoing.
    var savedNote = "What you said is saved. No need to record again."
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(failure == nil ? eyebrow : "Paused")
                            .onboardingLabel()
                        Text(failure == nil ? headline : "That didn’t go through.")
                            .onboardingHeadline()
                            .accessibilityAddTraits(.isHeader)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(steps) { step in
                            OnboardingRailRow(step: step, isLast: step.id == steps.last?.id)
                        }
                    }
                    .padding(.top, 40)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, OnboardingStyle.gutter)
                .padding(.top, 40)
            }
            if failure != nil {
                failureFooter
            } else {
                promiseFooter
            }
        }
    }

    /// "While you wait" and the promise line, under a hairline.
    private var promiseFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("While you wait").onboardingLabel()
            Text(footer)
                .font(OnboardingStyle.display(22))
                .tracking(22 * -0.02)
                .foregroundColor(OnboardingStyle.text)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, OnboardingStyle.gutter)
        .padding(.top, 24)
        .padding(.bottom, 48)
        .overlay(alignment: .top) {
            Rectangle().fill(OnboardingStyle.hairline).frame(height: 0.5)
        }
        .accessibilityElement(children: .combine)
    }

    private var failureFooter: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(OnboardingStyle.text)
                    .frame(width: 16, height: 16)
                Text(savedNote)
                    .onboardingCaption(OnboardingStyle.text)
                    .lineSpacing(3)
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

/// A step on the rail: a 20-point circle (ticked, current, empty or "!"),
/// joined to the next step's circle by a thin line behind them.
struct OnboardingRailRow: View {
    let step: OnboardingRailStep
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                marker
                if !isLast {
                    Rectangle()
                        .fill(OnboardingStyle.hairline)
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 20)

            VStack(alignment: .leading, spacing: 8) {
                Text(step.title)
                    .font(isCurrent ? OnboardingStyle.bodyMedium : OnboardingStyle.body)
                    .foregroundColor(isCurrent ? OnboardingStyle.text : OnboardingStyle.secondary)
                    .frame(minHeight: 20)
                if step.state == .failed {
                    Text("This step didn’t finish. It’s on our side, not yours.")
                        .onboardingCaption()
                        .lineSpacing(3)
                }
                ForEach(Array(step.lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .onboardingCaption()
                        .transition(.opacity)
                }
            }
            .padding(.bottom, isLast ? 0 : 24)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(accessibilityState)
    }

    private var isCurrent: Bool { step.state == .active || step.state == .failed }

    @ViewBuilder
    private var marker: some View {
        switch step.state {
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(OnboardingStyle.secondary)
                .frame(width: 20, height: 20)
                .background(Circle().fill(OnboardingStyle.hairline))
        case .active:
            Circle()
                .fill(OnboardingStyle.text)
                .frame(width: 8, height: 8)
                .frame(width: 20, height: 20)
                .background(Circle().fill(OnboardingStyle.background))
                .overlay(Circle().strokeBorder(OnboardingStyle.text, lineWidth: 1.5))
        case .pending:
            Circle()
                .fill(OnboardingStyle.background)
                .overlay(Circle().strokeBorder(OnboardingStyle.hairline, lineWidth: 1.5))
                .frame(width: 20, height: 20)
        case .failed:
            Text("!")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(OnboardingStyle.text)
                .frame(width: 20, height: 20)
                .background(Circle().fill(OnboardingStyle.background))
                .overlay(Circle().strokeBorder(OnboardingStyle.text, lineWidth: 1.5))
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

    private var isTyped: Bool { viewModel.progress.transcriptSource == .typed }

    var body: some View {
        OnboardingLoadingLayout(
            eyebrow: "Working on it · About 10 sec",
            headline: "Listening back",
            steps: steps,
            footer: "From here on, it sorts itself.",
            failure: viewModel.progress.failure,
            savedNote: isTyped
                ? "What you wrote is saved. No need to type it again."
                : "What you said is saved. No need to record again.",
            onRetry: { Task { await viewModel.retryFailedStep() } }
        )
        .animation(.easeInOut(duration: 0.25), value: viewModel.heardLinesShown)
        .animation(.easeInOut(duration: 0.25), value: viewModel.isCheckDone)
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
            .map { "Heard “\($0)”" }
        var steps = [
            OnboardingRailStep(id: 1, title: "Picking out what you’re juggling", state: read, lines: heard),
            OnboardingRailStep(id: 2, title: "Checking what you might have missed", state: check)
        ]
        // Typed text has nothing to transcribe, so that step isn't shown.
        if !isTyped {
            steps.insert(OnboardingRailStep(id: 0, title: "Transcribing what you said", state: transcribe), at: 0)
        }
        return steps
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
            footer: "Talk once. It handles the rest.",
            failure: viewModel.progress.failure,
            savedNote: "Your answers are saved. No need to answer again.",
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
