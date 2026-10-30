import SwiftUI

/// The Dump and Browse tabs, with the app's own flat tab bar (TDTabBar)
/// instead of the system one. Each tab's root screen adds the bar itself
/// (`.appTabBar()`), so it shows only on the two roots and a pushed screen
/// covers it. Both tabs stay alive once opened, so each keeps its place.
struct MainTabView: View {
    @State private var selection: AppTab = .dump
    /// Browse is built the first time it's opened, not at launch.
    @State private var hasOpenedBrowse = false

    var body: some View {
        ZStack {
            tab(.dump) {
                ContentView()
            }
            if hasOpenedBrowse {
                tab(.browse) {
                    BrowseView()
                }
            }
        }
        .environment(\.appTabSelection, Binding(
            get: { selection },
            set: { newTab in
                if newTab == .browse { hasOpenedBrowse = true }
                selection = newTab
            }
        ))
    }

    private func tab<Content: View>(_ tab: AppTab, @ViewBuilder content: () -> Content) -> some View {
        let isActive = tab == selection
        return content()
            .environment(\.isActiveTab, isActive)
            .opacity(isActive ? 1 : 0)
            .allowsHitTesting(isActive)
            .accessibilityHidden(!isActive)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
        .environmentObject(CategoryRecategorizationTracker.shared)
}
