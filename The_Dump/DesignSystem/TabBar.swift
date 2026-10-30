import SwiftUI

/// The two main tabs. The app draws its own flat tab bar (Paper, "Design
/// system pass — iOS") because the system one is Liquid Glass and floats.
enum AppTab: Hashable, CaseIterable {
    case dump
    case browse

    var title: String {
        switch self {
        case .dump: return "Dump"
        case .browse: return "Browse"
        }
    }

    var systemImage: String {
        switch self {
        case .dump: return "tray"
        case .browse: return "folder"
        }
    }
}

private struct AppTabSelectionKey: EnvironmentKey {
    static let defaultValue: Binding<AppTab>? = nil
}

private struct IsActiveTabKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Set by MainTabView. Nil in previews and sheets, where no tab bar shows.
    var appTabSelection: Binding<AppTab>? {
        get { self[AppTabSelectionKey.self] }
        set { self[AppTabSelectionKey.self] = newValue }
    }

    /// Whether this tab is the one on screen. MainTabView keeps both tabs
    /// alive so each keeps its place, so a hidden tab never "disappears";
    /// a screen that refreshed on appearing watches this instead.
    var isActiveTab: Bool {
        get { self[IsActiveTabKey.self] }
        set { self[IsActiveTabKey.self] = newValue }
    }
}

extension View {
    /// Puts the tab bar under a tab's root screen. Only the Dump and Browse
    /// roots call this, so a pushed screen slides over the bar and hides it.
    func appTabBar() -> some View {
        modifier(AppTabBarModifier())
    }
}

private struct AppTabBarModifier: ViewModifier {
    @Environment(\.appTabSelection) private var selection

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            if let selection {
                TDTabBar(selection: selection)
            }
        }
    }
}

/// An icon over a 10pt label, with a hairline on top. The active tab is
/// primary text with a medium label; the others are secondary text. Never
/// amber.
struct TDTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let isActive = tab == selection
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: Theme.spacingXS) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 22, weight: .regular))
                            .frame(height: 24)
                        Text(tab.title)
                            .font(.system(size: 10, weight: isActive ? .medium : .regular))
                    }
                    .foregroundStyle(isActive ? Theme.textPrimary : Theme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(TDPressStyle())
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isTabBar)
        .overlay(alignment: .top) {
            TDHairline()
        }
        .background(Theme.background.ignoresSafeArea(edges: .bottom))
    }
}

#Preview {
    VStack {
        Spacer()
        TDTabBar(selection: .constant(.dump))
    }
    .background(Theme.background)
}
