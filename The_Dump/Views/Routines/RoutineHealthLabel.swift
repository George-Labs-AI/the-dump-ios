import SwiftUI

/// The routine runner's health in plain words ("Up to date · 42m ago",
/// "Not running"…), worded and coloured like the web's status chip. Draws
/// nothing when the server sent no status or a code this app doesn't know.
struct RoutineHealthLabel: View {
    let status: RoutineStatus?

    var body: some View {
        if let health = RoutineHealth(status: status),
           let text = RoutineHealth.displayText(for: status) {
            Text(text)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color(for: health))
                .padding(.horizontal, Theme.spacingSM)
                .padding(.vertical, 3)
                .background(color(for: health).opacity(0.12))
                .clipShape(Capsule())
                .accessibilityLabel("Status: \(text)")
        }
    }

    private func color(for health: RoutineHealth) -> Color {
        switch health {
        case .ok, .nothingToDo:
            return Theme.success
        case .partial, .unknown:
            return Theme.warning
        case .failed, .silent:
            return .red
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
    }
    .padding()
    .background(Theme.background)
}
