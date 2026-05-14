import SwiftUI

/// Amber banner shown during the 24h re-categorize window after a user edits
/// a category and asks the AI to re-run on past notes.
struct ReCategorizingBanner: View {
    let categoryName: String
    let affectedCount: Int?
    let onDismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: Theme.spacingSM) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundColor(Theme.warning)
                .font(.system(size: 16, weight: .semibold))
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: Theme.spacingXS) {
                Text("Re-categorizing \(categoryName)…")
                    .font(.system(size: Theme.fontSizeSM, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Text(detailText)
                    .font(.system(size: Theme.fontSizeXS))
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Theme.spacingSM)

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.textTertiary)
                        .padding(6)
                }
            }
        }
        .padding(Theme.spacingMD)
        .background(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusSM)
                .fill(Theme.warning.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cornerRadiusSM)
                .stroke(Theme.warning.opacity(0.4), lineWidth: 1)
        )
    }

    private var detailText: String {
        if let count = affectedCount {
            return "Sorting \(count) note\(count == 1 ? "" : "s"). Up to 24h. Notes affected show a badge until done."
        }
        return "Sorting past notes. Up to 24h. Notes affected show a badge until done."
    }
}

#Preview {
    ReCategorizingBanner(categoryName: "Ideas", affectedCount: 42, onDismiss: {})
        .padding()
        .background(Theme.background)
}
