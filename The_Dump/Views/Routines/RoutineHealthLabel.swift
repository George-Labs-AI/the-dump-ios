import SwiftUI

/// The routine runner's health in plain words ("Up to date · 42m ago",
/// "Not running"…), worded like the web's status chip and drawn as the
/// design system's one status pill: a mark plus the exact words, with tone
/// carried by the mark and the outline rather than colour. Says "Status
/// unavailable" when the server sent no status, as the web does, and draws
/// nothing for a code this app doesn't know.
struct RoutineHealthLabel: View {
    let status: RoutineStatus?

    var body: some View {
        switch RoutineStatusDisplay(status: status) {
        case .health(let health):
            let text = RoutineHealth.displayText(for: status) ?? health.label
            let look = Self.look(for: health, hasReport: status?.hasReport ?? false)
            TDStatusPill(
                mark: .symbol(look.symbol),
                text: text,
                isMuted: look.isMuted,
                needsAttention: look.needsAttention
            )
            .accessibilityLabel("Status: \(text)")
        case .unavailable:
            TDStatusPill(mark: .symbol("minus"), text: RoutineStatusDisplay.unavailableLabel, isMuted: true)
        case .hidden:
            EmptyView()
        }
    }

    struct Look: Equatable {
        let symbol: String
        var isMuted = false
        var needsAttention = false
    }

    /// The design system's marks for routine health: check for done,
    /// triangle for partly done, circle-alert for failed or silent, clock
    /// while waiting, pause when paused.
    static func look(for health: RoutineHealth, hasReport: Bool) -> Look {
        switch health {
        case .ok, .nothingToDo:
            return Look(symbol: "checkmark")
        case .partial:
            return Look(symbol: "exclamationmark.triangle", needsAttention: true)
        case .unknown:
            // "Result unclear" once a report exists; before that, waiting.
            return hasReport
                ? Look(symbol: "exclamationmark.triangle", needsAttention: true)
                : Look(symbol: "clock", isMuted: true)
        case .failed, .silent:
            return Look(symbol: "exclamationmark.circle", needsAttention: true)
        case .paused:
            return Look(symbol: "pause", isMuted: true)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Theme.spacingSM) {
        ForEach(RoutineHealth.allCases, id: \.self) { health in
            RoutineHealthLabel(status: RoutineStatus(verdict: health.rawValue))
            RoutineHealthLabel(status: RoutineStatus(
                verdict: health.rawValue,
                asOf: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-42 * 60)),
                silentForHours: 29
            ))
        }
        RoutineHealthLabel(status: nil)
    }
    .padding()
    .background(Theme.background)
}
