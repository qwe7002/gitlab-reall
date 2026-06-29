import SwiftUI

struct HomeView: View {
    @Environment(AppSession.self) private var session
    @State private var loader: PaginatedLoader<GitLabEvent>?

    var body: some View {
        NavigationStack {
            Group {
                if let loader {
                    content(loader)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Home")
        }
        .task {
            guard loader == nil, let api = session.api else { return }
            let l = PaginatedLoader<GitLabEvent> { try await api.events(page: $0) }
            loader = l
            await l.loadFirstIfNeeded()
        }
    }

    @ViewBuilder
    private func content(_ loader: PaginatedLoader<GitLabEvent>) -> some View {
        switch loader.phase {
        case .loading where loader.items.isEmpty:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message) where loader.items.isEmpty:
            MessageStateView(systemImage: "wifi.exclamationmark",
                             title: "Couldn't load activity",
                             message: message) {
                Task { await loader.reload() }
            }
        default:
            List {
                ForEach(loader.items) { event in
                    EventRow(event: event, host: session.api?.host)
                        .task { await loader.loadMoreIfNeeded(currentItem: event) }
                }
                if loader.isLoadingMore {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .listStyle(.plain)
            .refreshable { await loader.reload() }
            .overlay {
                if loader.items.isEmpty {
                    MessageStateView(systemImage: "clock.arrow.circlepath",
                                     title: "No recent activity",
                                     message: "Your GitLab activity will show up here.")
                }
            }
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
