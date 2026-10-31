import SwiftUI

/// The Dump and Browse tabs. The system tab view still runs them, so each tab
/// keeps its place and a hidden tab leaves the window (status-bar
/// scroll-to-top, the keyboard and appearing work as before), but its Liquid
/// Glass bar is hidden on both tabs, pushed screens included. Each tab's root
/// screen draws the flat TDTabBar itself (`.appTabBar()`), so the bar shows
/// only on the two roots.
struct MainTabView: View {
    @State private var selection: AppTab = .dump

    var body: some View {
        TabView(selection: $selection) {
            ContentView()
                .tag(AppTab.dump)
                .toolbar(.hidden, for: .tabBar)
            BrowseView()
                .tag(AppTab.browse)
                .toolbar(.hidden, for: .tabBar)
        }
        .environment(\.appTabSelection, $selection)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
        .environmentObject(CategoryRecategorizationTracker.shared)
}
