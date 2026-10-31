import SwiftUI

// Small pieces shared by the restyled screens, built to The Dump Design
// System. Press states follow its rule: white buttons go to 0.7 opacity;
// rows, text links and icon buttons go to 0.4; nothing changes colour or
// scale.

// MARK: - Buttons

/// The one primary action on a screen: a 56pt white pill with a black 17pt
/// medium label. Disabled is a surface fill with placeholder text, not
/// reduced opacity.
struct TDPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonBody(configuration: configuration)
    }

    private struct PrimaryButtonBody: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(isEnabled ? Theme.buttonPrimaryForeground : Theme.placeholder)
                .frame(maxWidth: .infinity, minHeight: Theme.buttonHeight)
                .background(Capsule().fill(isEnabled ? Theme.buttonPrimaryBackground : Theme.surface))
                .contentShape(Capsule())
                .opacity(configuration.isPressed ? 0.7 : 1)
        }
    }
}

/// A secondary action: grey text, never boxed, with a 44pt hit area.
struct TDTextLinkStyle: ButtonStyle {
    var color: Color = Theme.textSecondary
    var size: CGFloat = 17

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size))
            .foregroundStyle(color)
            .frame(minHeight: Theme.touchMin)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.4 : 1)
    }
}

/// Rows and icon buttons: the content as drawn, at 0.4 opacity while pressed.
struct TDPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.4 : 1)
    }
}

// MARK: - Lists

/// A small uppercase label over a group of rows ("PROCESSING", "CATEGORIES").
struct TDSectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .tdLabel()
            .foregroundStyle(Theme.textSecondary)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The 0.5pt divider between list rows.
struct TDHairline: View {
    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: Theme.hairlineWidth)
            .accessibilityHidden(true)
    }
}

// MARK: - Chips

/// A chip: 36pt tall, 8pt corners, 13pt text, with an optional count in grey
/// tabular digits. Selected is an inverted fill plus a check, so colour is
/// never the only sign.
struct TDChip: View {
    let title: String
    var count: Int?
    var isSelected = false
    @Environment(\.isEnabled) private var isEnabled

    private var titleColor: Color {
        if isSelected { return Theme.buttonPrimaryForeground }
        return isEnabled ? Theme.textPrimary : Theme.placeholder
    }

    private var countColor: Color {
        if isSelected { return Theme.buttonPrimaryForeground }
        return isEnabled ? Theme.textSecondary : Theme.placeholder
    }

    var body: some View {
        HStack(spacing: Theme.spacingXS) {
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .regular))
            }
            Text(title)
            if let count {
                Text("\(count)")
                    .monospacedDigit()
                    .foregroundStyle(countColor)
            }
        }
        .font(.system(size: 13))
        .lineLimit(1)
        .foregroundStyle(titleColor)
        .padding(.horizontal, Theme.spacingSMPlus)
        .frame(height: 36)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusTag)
                .fill(isSelected ? Theme.buttonPrimaryBackground : Theme.raised)
        )
        // Drawn 36pt tall, tapped as 44pt. In a wrapping row, 0 line spacing
        // gives the design's 8pt gap between rows.
        .padding(.vertical, (Theme.touchMin - 36) / 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The dashed "+ Add" chip at the end of a row of chips.
struct TDAddChip: View {
    var title = "Add"

    var body: some View {
        HStack(spacing: Theme.spacingXS) {
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .regular))
            Text(title)
        }
        .font(.system(size: 13))
        .foregroundStyle(Theme.textSecondary)
        .padding(.horizontal, Theme.spacingSMPlus)
        .frame(height: 36)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusTag)
                .strokeBorder(Theme.placeholder, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        )
        .padding(.vertical, (Theme.touchMin - 36) / 2)
        .contentShape(Rectangle())
    }
}

// MARK: - Categories

/// A category's own emoji, or a grey folder symbol when it has none (most
/// categories, until the AI picks one: THEDUMP-145). The emoji is the
/// person's content; the stand-in is an SF Symbol, never the 📁 emoji.
struct CategoryGlyph: View {
    let emoji: String?
    var size: CGFloat = 17

    var body: some View {
        if let emoji = emoji?.trimmingCharacters(in: .whitespacesAndNewlines), !emoji.isEmpty {
            Text(emoji)
                .font(.system(size: size))
                .accessibilityHidden(true)
        } else {
            Image(systemName: "folder")
                .font(.system(size: size - 2, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Theme.spacingMD) {
        TDSectionLabel(title: "Categories")
        HStack(spacing: Theme.spacingSM) {
            TDChip(title: "All", isSelected: true)
            TDChip(title: "consumer", count: 6)
            TDAddChip()
        }
        HStack(spacing: 6) {
            CategoryGlyph(emoji: "💡")
            Text("Business Ideas").foregroundStyle(Theme.textPrimary)
        }
        HStack(spacing: 6) {
            CategoryGlyph(emoji: nil)
            Text("No emoji yet").foregroundStyle(Theme.textPrimary)
        }
        TDHairline()
        Button("Upload") {}
            .buttonStyle(TDPrimaryButtonStyle())
        Button("Discard") {}
            .buttonStyle(TDTextLinkStyle())
    }
    .padding(Theme.screenH)
    .background(Theme.background)
}
