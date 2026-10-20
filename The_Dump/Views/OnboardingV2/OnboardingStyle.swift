import SwiftUI

/// The look of the onboarding, from the "(dark v1)" screens in the Paper
/// file The_Dump_Onboarding (D-071). It has its own colours rather than the
/// app's `Theme`, because onboarding is always dark whatever the phone's
/// setting.
///
/// Fonts: the design uses Inter for text and Instrument Sans for headlines.
/// Neither is bundled with the app, so both use the system font (SF Pro) at
/// the design's sizes, weights and letter spacing.
enum OnboardingStyle {
    // MARK: Colours (the Paper file's tokens)
    static let background = Color(hex: "000000")
    static let surface = Color(hex: "1C1C1E")
    static let hairline = Color(hex: "2C2C2E")
    static let text = Color(hex: "F5F5F7")
    static let secondary = Color(hex: "8E8E93")
    static let placeholder = Color(hex: "6E6E73")
    static let danger = Color(hex: "FF453A")

    // MARK: Spacing and shape
    static let gutter: CGFloat = 24
    static let cardRadius: CGFloat = 14
    static let cardPadding: CGFloat = 20
    static let buttonHeight: CGFloat = 56

    // MARK: Type
    /// Instrument Sans headlines: tight tracking (-0.04em).
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .regular) }
    static func displayTracking(_ size: CGFloat) -> CGFloat { size * -0.04 }

    static let body = Font.system(size: 16, weight: .regular)
    static let bodyMedium = Font.system(size: 16, weight: .medium)
    static let caption = Font.system(size: 13, weight: .regular)
    static let label = Font.system(size: 11, weight: .medium)
    /// Small capitals labels: 11px, tracking 0.12em.
    static let labelTracking: CGFloat = 11 * 0.12
    static let button = Font.system(size: 17, weight: .medium)
}

// MARK: - Text styles

extension Text {
    /// A screen headline (Instrument Sans in the design).
    func onboardingHeadline(_ size: CGFloat = 40, lineHeight: CGFloat = 40) -> some View {
        self.font(OnboardingStyle.display(size))
            .tracking(OnboardingStyle.displayTracking(size))
            .foregroundColor(OnboardingStyle.text)
            .lineSpacing(max(0, lineHeight - size * 1.2))
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Body copy: 16/24, secondary grey unless told otherwise.
    func onboardingBody(_ color: Color = OnboardingStyle.secondary) -> some View {
        self.font(OnboardingStyle.body)
            .foregroundColor(color)
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Small uppercase label: 11px medium, tracking 0.12em.
    func onboardingLabel(_ color: Color = OnboardingStyle.secondary) -> some View {
        self.font(OnboardingStyle.label)
            .tracking(OnboardingStyle.labelTracking)
            .textCase(.uppercase)
            .foregroundColor(color)
    }

    func onboardingCaption(_ color: Color = OnboardingStyle.secondary) -> some View {
        self.font(OnboardingStyle.caption)
            .foregroundColor(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Buttons

/// The white, full-width, pill-shaped main button. Disabled, it turns the
/// dark grey of the locked Finish button.
struct OnboardingPrimaryButtonStyle: ButtonStyle {
    var isEnabled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(OnboardingStyle.button)
            .foregroundColor(isEnabled ? OnboardingStyle.background : OnboardingStyle.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: OnboardingStyle.buttonHeight)
            .background(
                Capsule().fill(isEnabled ? OnboardingStyle.text : OnboardingStyle.surface)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// A plain grey text link ("Type instead", "Skip").
struct OnboardingLinkStyle: ButtonStyle {
    var color: Color = OnboardingStyle.secondary
    var font: Font = OnboardingStyle.caption

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(font)
            .foregroundColor(color)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Rectangle())
    }
}

// MARK: - Shared pieces

/// The three-part progress bar on screens 2 to 4.
struct OnboardingProgressBar: View {
    /// 1, 2 or 3.
    let filled: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index <= filled ? OnboardingStyle.text : OnboardingStyle.hairline)
                    .frame(height: 2)
            }
        }
        .padding(.horizontal, OnboardingStyle.gutter)
        .padding(.top, 8)
        .accessibilityElement()
        .accessibilityLabel("Step \(filled) of 3")
    }
}

/// The round white microphone button (96 across on screen 2).
struct OnboardingMicButton: View {
    var size: CGFloat = 96
    var iconSize: CGFloat = 32
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "mic")
                .font(.system(size: iconSize * 0.75, weight: .regular))
                .foregroundColor(OnboardingStyle.background)
                .frame(width: size, height: size)
                .background(Circle().fill(OnboardingStyle.text))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Record")
    }
}

extension View {
    /// A dark grey card with the design's radius and padding.
    func onboardingCard(padding: CGFloat = OnboardingStyle.cardPadding) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: OnboardingStyle.cardRadius)
                    .fill(OnboardingStyle.surface)
            )
    }
}
