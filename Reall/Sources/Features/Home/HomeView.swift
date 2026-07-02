import SwiftUI

struct HomeView: View {
    @Environment(AppSession.self) private var session
    @State private var loader: PaginatedLoader<GitLabEvent>?
    @State private var showingProfile = false

    var body: some View {
        NavigationStack {
            List {
                Section("My Work") {
                    NavigationLink { MyIssuesScreen() } label: {
                        DashboardLabel("Issues", systemImage: "smallcircle.filled.circle", color: .green)
                    }
                    NavigationLink { MyMergeRequestsScreen() } label: {
                        DashboardLabel("Merge Requests", systemImage: "arrow.triangle.pull", color: .blue)
                    }
                    NavigationLink { CIDashboardView() } label: {
                        DashboardLabel("Pipelines", systemImage: "bolt.horizontal.fill", color: .orange)
                    }
                }

                Section("Recent activity") {
                    activitySection
                }
            }
            .navigationTitle("Home")
            .navigationDestination(for: Route.self) { $0.destination }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingProfile = true } label: {
                        AvatarView(url: session.currentUser?.avatarURL,
                                   fallbackText: session.currentUser?.displayName ?? "?",
                                   size: 30)
                    }
                    .accessibilityLabel("Profile")
                }
            }
            .refreshable { await loader?.reload() }
            .sheet(isPresented: $showingProfile) { ProfileView() }
        }
        .task {
            guard loader == nil, let api = session.api else { return }
            let l = PaginatedLoader<GitLabEvent> { try await api.events(page: $0) }
            loader = l
            await l.loadFirstIfNeeded()
        }
    }

    @ViewBuilder
    private var activitySection: some View {
        if let loader {
            if !loader.items.isEmpty {
                ForEach(loader.items) { event in
                    EventRow(event: event, host: session.api?.host)
                        .task { await loader.loadMoreIfNeeded(currentItem: event) }
                }
                if loader.isLoadingMore {
                    ProgressView().frame(maxWidth: .infinity)
                }
            } else {
                switch loader.phase {
                case .idle, .loading:
                    ProgressView().frame(maxWidth: .infinity)
                case .failed(let message):
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                case .loaded:
                    Text("Your GitLab activity will show up here.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        } else {
            ProgressView().frame(maxWidth: .infinity)
        }
    }
}

/// A list row with a rounded, colour-filled icon tile, GitHub dashboard style.
struct DashboardLabel: View {
    let title: String
    let systemImage: String
    let color: Color

    init(_ title: String, systemImage: String, color: Color) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(color)
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
            Text(title)
        }
    }
}

struct EventRow: View {
    let event: GitLabEvent
    let host: URL?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(url: event.author?.avatarURL,
                       fallbackText: event.author?.displayName ?? "?",
                       size: 36)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: event.iconName)
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                    Text(event.author?.displayName ?? "Someone")
                        .font(.subheadline.weight(.semibold))
                    Text(event.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let title = event.targetTitle ?? event.pushData?.commitTitle, !title.isEmpty {
                    Text(title)
                        .font(.subheadline)
                        .lineLimit(2)
                }
                RelativeDateText(date: event.createdAt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}
