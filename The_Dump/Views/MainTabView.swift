import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Dump", systemImage: "square.and.pencil")
                }
            
            BrowseView()
                .tabItem {
                    Label("Browse", systemImage: "folder")
                }
        }
        .tint(Theme.accent)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
}
