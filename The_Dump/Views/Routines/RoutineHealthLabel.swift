import SwiftUI

/// The routine runner's health in plain words ("Up to date · 42m ago",
/// "Not running"…), worded and coloured like the web's status chip. Says
/// "Status unavailable" when the server sent no status, as the web does,
/// and draws nothing for a code this app doesn't know.
struct RoutineHealthLabel: View {
    let status: RoutineStatus?

    var body: some View {
        switch RoutineStatusDisplay(status: status) {
        case .health(let health):
            let text = RoutineHealth.displayText(for: status) ?? health.label
            chip(text, color: color(for: health), accessibilityLabel: "Status: \(text)")
        case .unavailable:
            chip(
                RoutineStatusDisplay.unavailableLabel,
                color: Theme.textSecondary,
                accessibilityLabel: RoutineStatusDisplay.unavailableLabel
            )
        case .hidden:
            EmptyView()
        }
    }

    private func chip(_ label: String, color: Color, accessibilityLabel: String) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, Theme.spacingSM)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .accessibilityLabel(accessibilityLabel)
    }

    private func color(for health: RoutineHealth) -> Color {
        switch health {
        case .ok, .nothingToDo:
            return Theme.success
        case .partial, .unknown:
            return Theme.warning
        case .failed, .silent:
            return Theme.textPrimary
        case .paused:
            return Theme.textSecondary
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
