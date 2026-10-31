import SwiftUI

// "Connect your runner": the instructions a routine's runner needs, with
// Copy and Share. A runner is the owner's own code on a computer or server,
// so the phone only hands the instructions over; connecting is finished on
// a computer. Mirrors the web's /routines/<slug>/connect page.

struct RoutineConnectView: View {
    /// The few routine fields this screen shows, from either routine model.
    struct Routine {
        let slug: String
        let routineID: String
        let name: String
        let description: String?

        init(_ summary: RoutineSummary) {
            slug = summary.slug
            routineID = summary.routineID
            name = summary.name
            description = summary.description
        }

        init(_ detail: RoutineDetailResponse) {
            slug = detail.slug
            routineID = detail.routineID
            name = detail.name
            description = detail.description
        }
    }

    private let routine: Routine
    /// Set when the routine was just created: shows the "is registered"
    /// banner and a Done button that closes the create flow.
    private let onDone: (() -> Void)?
    @StateObject private var viewModel: RoutineConnectViewModel
    @State private var copied = false

    init(routine: Routine, onDone: (() -> Void)? = nil) {
        self.routine = routine
        self.onDone = onDone
        _viewModel = StateObject(wrappedValue: RoutineConnectViewModel(slug: routine.slug))
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingMD) {
                    if onDone != nil {
                        registeredBanner
                    }
                    instructionsCard
                    routineCard
                }
                .padding(Theme.spacingMD)
            }
        }
        .navigationTitle("Connect your runner")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationBarBackButtonHidden(onDone != nil)
        .toolbar {
            if let onDone {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDone)
                        .foregroundColor(Theme.accent)
                }
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var registeredBanner: some View {
        VStack(alignment: .leading, spacing: Theme.spacingXS) {
            Text("\(routine.name) is registered.")
                .font(.system(size: Theme.fontSizeMD, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
            Text("Connect your own runner to start generating results. The Dump stores your inputs and outputs; your runner does the work on your schedule.")
                .font(.system(size: Theme.fontSizeSM))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.spacingMD)
        .background(Theme.success.opacity(0.12))
        .cornerRadius(Theme.cornerRadius)
    }

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSMPlus) {
            Text("Finish connecting on a computer")
                .font(.system(size: Theme.fontSizeLG, weight: .semibold))
                .foregroundColor(Theme.textPrimary)

            Text("Your runner is your own code, running on a computer or a server. Copy or share these instructions to that computer, then paste them into your coding assistant or runner project. They include your routine's configuration, exact endpoints, sign-in steps, and the rules for publishing results.")
                .font(.system(size: Theme.fontSizeSM))
                .foregroundColor(Theme.textSecondary)

            if let instructions = viewModel.instructions {
                HStack(spacing: Theme.spacingSM) {
                    Button {
                        UIPasteboard.general.string = instructions
                        copied = true
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    ShareLink(
                        item: instructions,
                        subject: Text("Runner instructions for \(routine.name)"),
                        preview: SharePreview("Runner instructions for \(routine.name)")
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                if copied {
                    Text("Copied. Paste it into your runner project.")
                        .font(.system(size: Theme.fontSizeXS))
                        .foregroundColor(Theme.success)
                }

                DisclosureGroup("Read the full runner instructions") {
                    Text(instructions)
                        .font(.system(size: Theme.fontSizeXS, design: .monospaced))
                        .foregroundColor(Theme.textPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, Theme.spacingSM)
                }
                .font(.system(size: Theme.fontSizeSM, weight: .medium))
                .foregroundColor(Theme.textPrimary)
            } else if viewModel.isLoading {
                HStack(spacing: Theme.spacingSM) {
                    ProgressView()
                    Text("Loading the instructions…")
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(Theme.textSecondary)
                }
            } else if let error = viewModel.errorMessage {
                Label("Couldn't load the runner instructions: \(error)", systemImage: "exclamationmark.circle")
                    .font(.system(size: Theme.fontSizeSM))
                    .foregroundColor(Theme.textPrimary)
                Button("Retry") {
                    Task { await viewModel.load() }
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            Text("Includes the shared Firebase configuration. Personal passwords and tokens are never included.")
                .font(.system(size: Theme.fontSizeXS))
                .foregroundColor(Theme.textTertiary)

            if let url = RoutineLinks.connectPageURL(slug: routine.slug) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("The same instructions are on this page, for your computer:")
                        .font(.system(size: Theme.fontSizeXS))
                        .foregroundColor(Theme.textTertiary)
                    Text(url.absoluteString)
                        .font(.system(size: Theme.fontSizeXS, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(Theme.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .cornerRadius(Theme.cornerRadius)
    }

    private var routineCard: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSMPlus) {
            Text("Your routine")
                .font(.system(size: Theme.fontSizeLG, weight: .semibold))
                .foregroundColor(Theme.textPrimary)

            detailRow("Name", routine.name)
            detailRow("Description", nonBlank(routine.description) ?? "No description provided.")
            detailRow("Routine ID", routine.routineID, monospaced: true)
            detailRow("URL slug", routine.slug, monospaced: true)
        }
        .padding(Theme.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .cornerRadius(Theme.cornerRadius)
    }

    private func detailRow(_ label: String, _ value: String, monospaced: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: Theme.fontSizeXS, weight: .medium))
                .foregroundColor(Theme.textTertiary)
            Text(value)
                .font(.system(size: Theme.fontSizeSM, design: monospaced ? .monospaced : .default))
                .foregroundColor(Theme.textPrimary)
                .textSelection(.enabled)
        }
    }

    private func nonBlank(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
