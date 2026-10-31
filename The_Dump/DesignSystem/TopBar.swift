import SwiftUI
import UIKit

/// The top bar of a pushed screen (Paper, 03 Category and 04 Note): a plain
/// "‹ Back-title" on the left and the screen's actions on the right, 44pt
/// tall. Screens that use it hide the system navigation bar, whose Liquid
/// Glass buttons don't match the design.
struct TDTopBar<Trailing: View>: View {
    let backTitle: String
    @ViewBuilder var trailing: () -> Trailing
    @Environment(\.dismiss) private var dismiss

    init(backTitle: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.backTitle = backTitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 0) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: Theme.spacingXS) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .regular))
                    Text(backTitle)
                        .font(.system(size: 16))
                        .lineLimit(1)
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.trailing, Theme.spacingSM)
                .frame(height: Theme.touchMin)
                .contentShape(Rectangle())
            }
            .buttonStyle(TDPressStyle())
            .accessibilityLabel("Back to \(backTitle)")

            Spacer(minLength: Theme.spacingSM)

            trailing()
        }
        .frame(height: 44)
        .padding(.horizontal, Theme.spacingSMPlus)
    }
}

extension TDTopBar where Trailing == EmptyView {
    init(backTitle: String) {
        self.init(backTitle: backTitle) { EmptyView() }
    }
}

/// The "•••" that opens a screen's menu: grey, in a 44pt square.
struct TDMoreLabel: View {
    var body: some View {
        Image(systemName: "ellipsis")
            .font(.system(size: 20, weight: .regular))
            .foregroundStyle(Theme.textSecondary)
            .frame(width: Theme.touchMin, height: Theme.touchMin)
            .contentShape(Rectangle())
            .accessibilityLabel("More")
    }
}

/// Screens with TDTopBar hide the system navigation bar, and UIKit turns the
/// swipe-from-the-edge back gesture off with it. This turns it back on for
/// every pushed screen (never on a stack's first screen, where it would
/// freeze the stack). Checked in the simulator on 2026-10-30.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
