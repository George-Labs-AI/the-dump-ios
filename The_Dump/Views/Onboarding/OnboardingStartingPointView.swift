import SwiftUI

struct OnboardingStartingPointView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onContinue: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: Theme.spacingMD),
        GridItem(.flexible(), spacing: Theme.spacingMD)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Theme.spacingSM) {
                Text("Pick a starting point")
                    .font(.system(size: Theme.fontSizeXXL, weight: .bold))
                    .foregroundColor(Theme.textPrimary)

                Text("We'll personalize as you dump.")
                    .font(.system(size: Theme.fontSizeMD))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.top, Theme.spacingXL)
            .padding(.bottom, Theme.spacingLG)

            // Preset Cards
            ScrollView {
                LazyVGrid(columns: columns, spacing: Theme.spacingMD) {
                    ForEach(OnboardingPresets.allPresets) { preset in
                        PresetCard(
                            preset: preset,
                            isSelected: viewModel.isPresetSelected(preset),
                            onTap: { viewModel.selectPreset(preset) }
                        )
                    }
                }
                .padding(.horizontal, Theme.spacingMD)
            }

            Spacer()

            // Footer
            VStack(spacing: Theme.spacingMD) {
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.system(size: Theme.fontSizeSM))
                        .foregroundColor(Theme.accent)
                        .multilineTextAlignment(.center)
                }

                Text("You can change these anytime. After ~20 notes, we'll suggest better categories based on your content.")
                    .font(.system(size: Theme.fontSizeXS))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.spacingMD)

                Button(action: onContinue) {
                    if viewModel.isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.textPrimary))
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(PrimaryButtonStyle(isEnabled: viewModel.selectedPresetId != nil))
                .disabled(viewModel.selectedPresetId == nil || viewModel.isSubmitting)
                .padding(.horizontal, Theme.spacingMD)
            }
            .padding(.bottom, Theme.spacingLG)
        }
    }
}

// MARK: - Preset Card

private struct PresetCard: View {
    let preset: OnboardingPreset
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Theme.spacingSM) {
                Image(systemName: preset.icon)
                    .font(.system(size: 28))
                    .foregroundColor(isSelected ? Theme.accent : Theme.textSecondary)

                Text(preset.title)
                    .font(.system(size: Theme.fontSizeMD, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)

                Text(preset.previewText)
                    .font(.system(size: Theme.fontSizeXS))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.spacingMD)
            .background(Theme.surface)
            .cornerRadius(Theme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .stroke(isSelected ? Theme.accent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
