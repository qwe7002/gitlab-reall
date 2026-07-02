import SwiftUI

/// GitHub-app style bottom tab bar.
struct MainTabView: View {
    enum Tab: Hashable {
        case home, inbox, ci, explore, profile
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

            CIDashboardView()
                .tabItem { Label("CI", systemImage: "bolt.horizontal.fill") }
                .tag(Tab.ci)

            ExploreView()
                .tabItem { Label("Explore", systemImage: "magnifyingglass") }
                .tag(Tab.explore)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
                .tag(Tab.profile)
        }
    }
}
