import SwiftUI
import Combine

enum Theme {
    // MARK: - Colors (from Asset Catalog)
    // The Dump Design System palette. The app is dark-only for now, so only
    // the dark values show; the light values are its light mapping, kept for
    // when light mode comes back (THEDUMP-143).
    static let background = Color("background")         // bg #000000
    static let surface = Color("surface")               // surface #1C1C1E
    static let surface2 = Color("surface2")             // raised #2C2C2E
    static let surface3 = Color("surface3")             // raised #2C2C2E
    static let border = Color("border")                 // hairline #2C2C2E
    static let borderLight = Color("borderLight")       // hairline #2C2C2E
    static let textPrimary = Color("textPrimary")       // #F5F5F7
    static let textSecondary = Color("textSecondary")   // #8E8E93
    static let textTertiary = Color("textTertiary")     // placeholder #6E6E73
    static let textQuaternary = Color("textQuaternary") // placeholder #6E6E73
    /// Amber means "your stuff" and nothing else: a note that just landed, a
    /// count that just changed. Never buttons, links, icons or decoration.
    static let amber = Color("amber")
    /// Destructive actions only (Delete). Errors stay monochrome.
    static let destructive = Color("destructive")

    // MARK: - Design system names
    static let raised = surface2
    static let hairline = border
    /// Placeholders and disabled text only, never information (3.4:1).
    static let placeholder = textTertiary
    static let buttonPrimaryBackground = textPrimary
    static let buttonPrimaryForeground = background

    // MARK: - Old names, mapped onto the monochrome palette
    // The pink accent and the green, orange, blue and purple status colours
    // are gone: the design system is monochrome, and a status is an icon plus
    // a word. These names stay until each screen is restyled (THEDUMP-144).
    static let accent = Color("AccentColor")
    static let accentSubtle = Color("AccentColor").opacity(0.08)
    static let success = textPrimary
    static let warning = textPrimary
    static let info = textPrimary
    static let purple = textPrimary

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
    static let cardPadding: CGFloat = 20

    // MARK: - Sizes
    static let hairlineWidth: CGFloat = 0.5
    static let buttonHeight: CGFloat = 56
    static let touchMin: CGFloat = 44

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
    // Design system radii: tags and chips 8, inputs 12, cards 14; buttons,
    // the mic, the capture field and pills are fully rounded (Capsule).
    static let radiusTag: CGFloat = 8
    static let radiusInput: CGFloat = 12
    static let radiusCard: CGFloat = 14
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

// MARK: - Design system type
extension Font {
    /// Instrument Sans 400, the display face for headlines. The font file is
    /// bundled in Fonts/ and registered at launch (DesignFonts); if that ever
    /// fails, iOS falls back to the system font at the same size.
    static func display(_ size: CGFloat) -> Font {
        .custom(DesignFonts.displayName, fixedSize: size)
    }
}

extension Text {
    /// td-hero: 52, for the promise and done moments.
    func tdHero() -> some View {
        self.font(.display(52)).tracking(52 * -0.04)
    }

    /// td-headline: 40, every screen headline.
    func tdHeadline() -> some View {
        self.font(.display(40)).tracking(40 * -0.04)
    }

    /// td-title: 22, secondary headlines.
    func tdTitle() -> some View {
        self.font(.display(22)).tracking(22 * -0.04)
    }

    /// td-body: 16 on a 24 line. Note text is always regular.
    func tdBody() -> some View {
        self.font(.system(size: 16)).lineSpacing(24 - 19)
    }

    /// td-button: 17 medium.
    func tdButton() -> some View {
        self.font(.system(size: 17, weight: .medium))
    }

    /// td-caption: 13 on an 18 line.
    func tdCaption() -> some View {
        self.font(.system(size: 13)).lineSpacing(18 - 16)
    }

    /// td-label: 11 medium, uppercase, +0.12em.
    func tdLabel() -> some View {
        self.font(.system(size: 11, weight: .medium))
            .tracking(11 * 0.12)
            .textCase(.uppercase)
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
            // Disabled is a surface fill with placeholder text, as in the
            // design system; black text on the grey fill was unreadable.
            .foregroundColor(isEnabled ? Theme.background : Theme.placeholder)
            .padding(.horizontal, Theme.spacingLG)
            .padding(.vertical, Theme.spacingMD)
            .background(isEnabled ? (configuration.isPressed ? Theme.textPrimary.opacity(0.7) : Theme.textPrimary) : Theme.surface)
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
            .background(Theme.surface2)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusSM)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .cornerRadius(Theme.cornerRadiusSM)
            .opacity(configuration.isPressed ? 0.7 : 1)
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
