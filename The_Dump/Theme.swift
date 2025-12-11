import SwiftUI
import Combine

enum Theme {
    // MARK: - Colors
    static let background = Color(hex: "0d0d0d")
    static let darkGray = Color(hex: "1c1c1e")
    static let mediumGray = Color(hex: "2c2c2e")
    static let lightGray = Color(hex: "3a3a3c")
    static let textPrimary = Color(hex: "f2f2f2")
    static let textSecondary = Color(hex: "a0a0a0")
    static let accent = Color(hex: "ff2d55")
    static let accentHover = Color(hex: "e6254d")
    
    // MARK: - Spacing
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32
    
    // MARK: - Font Sizes
    static let fontSizeXS: CGFloat = 12
    static let fontSizeSM: CGFloat = 14
    static let fontSizeMD: CGFloat = 16
    static let fontSizeLG: CGFloat = 18
    static let fontSizeXL: CGFloat = 24
    static let fontSizeXXL: CGFloat = 32
    
    // MARK: - Corner Radius
    static let cornerRadius: CGFloat = 12
    static let cornerRadiusSM: CGFloat = 8
}

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

// MARK: - View Modifiers

struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: Theme.fontSizeMD, weight: .semibold))
            .foregroundColor(Theme.textPrimary)
            .padding(.horizontal, Theme.spacingLG)
            .padding(.vertical, Theme.spacingMD)
            .background(isEnabled ? (configuration.isPressed ? Theme.accentHover : Theme.accent) : Theme.lightGray)
            .cornerRadius(Theme.cornerRadius)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: Theme.fontSizeMD, weight: .medium))
            .foregroundColor(Theme.textPrimary)
            .padding(.horizontal, Theme.spacingLG)
            .padding(.vertical, Theme.spacingMD)
            .background(configuration.isPressed ? Theme.lightGray : Theme.mediumGray)
            .cornerRadius(Theme.cornerRadius)
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.spacingMD)
            .background(Theme.darkGray)
            .cornerRadius(Theme.cornerRadius)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}
