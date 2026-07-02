import SwiftUI

/// GitHub-app style bottom tab bar.
struct MainTabView: View {
    enum Tab: Hashable {
        case home, inbox, explore
    }

    @State private var selection: Tab = .home

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(Tab.home)

            InboxView()
                .tabItem { Label("Inbox", systemImage: "tray.full.fill") }
                .tag(Tab.inbox)

            ExploreView()
                .tabItem { Label("Explore", systemImage: "magnifyingglass") }
                .tag(Tab.explore)
        }
    }
}
