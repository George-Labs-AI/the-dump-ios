import SwiftUI

/// The design system's one status pill: 24pt tall, fully rounded, outlined,
/// with a mark and the exact word. It is monochrome, except amber for "your
/// stuff" (a note just organized into one of your categories).
struct TDStatusPill: View {
    enum Mark {
        /// An SF Symbol, such as "checkmark" or "arrow.up".
        case symbol(String)
        /// A small solid dot, for work under way. It does not pulse.
        case dot
    }

    let mark: Mark
    let text: String
    var isYourStuff = false
    /// Grey text for a quiet state, such as "Paused" or "Waiting for first
    /// report".
    var isMuted = false
    /// A primary-text outline instead of the hairline, for a state that
    /// wants attention ("Failed", "Not running"). Tone is carried by the
    /// mark and the outline, never by colour.
    var needsAttention = false

    private var foreground: Color {
        if isYourStuff { return Theme.amber }
        return isMuted ? Theme.textSecondary : Theme.textPrimary
    }

    var body: some View {
        HStack(spacing: Theme.spacingXS) {
            switch mark {
            case .symbol(let name):
                Image(systemName: name)
                    .font(.system(size: 11, weight: .regular))
                    .accessibilityHidden(true)
            case .dot:
                Circle()
                    .frame(width: 6, height: 6)
            }
            Text(text)
                .font(.system(size: 13))
                .lineLimit(1)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, Theme.spacingSM)
        .frame(height: 24)
        .overlay(Capsule().strokeBorder(needsAttention ? Theme.textPrimary : Theme.hairline, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// A thin progress bar for uploads and re-sorting: a raised track with a
/// primary-text fill.
struct TDMeter: View {
    /// From 0 to 1.
    let value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.raised)
                Capsule()
                    .fill(Theme.textPrimary)
                    .frame(width: geo.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 4)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int((min(max(value, 0), 1) * 100).rounded())) percent")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Theme.spacingMD) {
        TDStatusPill(mark: .symbol("checkmark"), text: "Organized → Business Ideas", isYourStuff: true)
        TDStatusPill(mark: .dot, text: "Organizing…")
        TDStatusPill(mark: .symbol("arrow.up"), text: "Uploading…")
        TDMeter(value: 0.62)
    }
    .padding(Theme.screenH)
    .background(Theme.background)
}
