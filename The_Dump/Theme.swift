import SwiftUI
import Combine

enum Theme {
    // MARK: - Colors (from Asset Catalog)
    static let background = Color("background")
    static let surface = Color("surface")
    static let surface2 = Color("surface2")
    static let surface3 = Color("surface3")
    static let border = Color("border")
    static let borderLight = Color("borderLight")
    static let textPrimary = Color("textPrimary")
    static let textSecondary = Color("textSecondary")
    static let textTertiary = Color("textTertiary")
    static let textQuaternary = Color("textQuaternary")
    static let accent = Color("AccentColor")
    static let accentSubtle = Color("AccentColor").opacity(0.08)
    static let success = Color("success")
    static let warning = Color("warning")
    static let info = Color("info")
    static let purple = Color("themePurple")

    // MARK: - Deprecated color aliases (temporary, for migration)
    static let darkGray = surface
    static let mediumGray = surface2
    static let lightGray = surface3
    static let accentHover = accent.opacity(0.9)

    // MARK: - Spacing
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingSMPlus: CGFloat = 12
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32
    static let spacingXXL: CGFloat = 48
    static let spacingXXXL: CGFloat = 64
    static let screenH: CGFloat = 24

    // MARK: - Font Sizes
    static let fontSizeXS: CGFloat = 12
    static let fontSizeSM: CGFloat = 14
    static let fontSizeMD: CGFloat = 16
    static let fontSizeLG: CGFloat = 18
    static let fontSizeXL: CGFloat = 24
    static let fontSizeXXL: CGFloat = 32

    // MARK: - Corner Radius
    static let cornerRadiusXS: CGFloat = 4
    static let cornerRadiusSM: CGFloat = 8
    static let cornerRadiusCatIcon: CGFloat = 10
    static let cornerRadius: CGFloat = 12
    static let cornerRadiusCapture: CGFloat = 16
    static let cornerRadiusPill: CGFloat = 20
}

// MARK: - Color(hex:) Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Typography Extensions
extension Text {
    func pageTitle() -> some View {
        self.font(.system(size: 36, weight: .heavy)).tracking(-1.5)
    }

    func screenTitle() -> some View {
        self.font(.system(size: 34, weight: .heavy)).tracking(-1.5)
    }

    func sectionTitle() -> some View {
        self.font(.system(size: 28, weight: .bold)).tracking(-1)
    }

    func noteTitle() -> some View {
        self.font(.system(size: 24, weight: .bold)).tracking(-0.8)
    }

    func cardTitle() -> some View {
        self.font(.system(size: 15, weight: .semibold))
    }

    func bodyText() -> some View {
        self.font(.system(size: 15, weight: .regular))
    }

    func cardPreview() -> some View {
        self.font(.system(size: 13, weight: .regular))
    }

    func sectionLabel() -> some View {
        self.font(.system(size: 10, weight: .semibold))
            .tracking(2)
            .textCase(.uppercase)
    }

    func metaCaption() -> some View {
        self.font(.system(size: 11, weight: .regular))
    }
}

// MARK: - View Modifiers

struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: Theme.fontSizeMD, weight: .semibold))
            .foregroundColor(Theme.background)
            .padding(.horizontal, Theme.spacingLG)
            .padding(.vertical, Theme.spacingMD)
            .background(isEnabled ? (configuration.isPressed ? Theme.textPrimary.opacity(0.8) : Theme.textPrimary) : Theme.surface3)
            .cornerRadius(Theme.cornerRadiusSM)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: Theme.fontSizeMD, weight: .medium))
            .foregroundColor(Theme.textPrimary)
            .padding(.horizontal, Theme.spacingLG)
            .padding(.vertical, Theme.spacingMD)
            .background(configuration.isPressed ? Theme.surface3 : Theme.surface2)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSM)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .cornerRadius(Theme.cornerRadiusSM)
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.spacingMD)
            .background(Theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                    .stroke(Theme.borderLight, lineWidth: 1)
            )
            .cornerRadius(Theme.cornerRadius)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}
