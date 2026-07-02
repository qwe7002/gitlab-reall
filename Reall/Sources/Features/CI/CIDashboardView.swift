import SwiftUI

/// CI home: the user's projects, each showing its latest pipeline status at a
/// glance, drilling into the full pipeline history.
struct CIDashboardView: View {
    @Environment(AppSession.self) private var session
    @State private var loader: PaginatedLoader<GitLabProject>?

    var body: some View {
        Group {
            if let loader {
                PagedListView(
                    loader: loader,
                    emptyTitle: "No projects",
                    emptyMessage: "Projects you're a member of will appear here.",
                    emptyImage: "bolt.horizontal"
                ) { project in
                    NavigationLink(value: Route.pipelines(project)) {
                        CIProjectRow(project: project)
                    }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Pipelines")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard loader == nil, let api = session.api else { return }
            let l = PaginatedLoader<GitLabProject> { try await api.myProjects(page: $0) }
            loader = l
            await l.loadFirstIfNeeded()
        }
    }
}

/// Project row that lazily loads and shows the latest pipeline's status.
struct CIProjectRow: View {
    @Environment(AppSession.self) private var session
    let project: GitLabProject

    @State private var latest: GitLabPipeline?
    @State private var didLoad = false

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: project.avatarURL, fallbackText: project.name, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(project.nameWithNamespace)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if let latest {
                    HStack(spacing: 6) {
                        let status = CIStatus(latest.status)
                        Image(systemName: status.symbolName)
                            .foregroundStyle(Theme.ciColor(status))
                        Text(status.label)
                        if let ref = latest.ref {
                            Text("· \(ref)").lineLimit(1)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else if didLoad {
                    Text("No pipelines").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Loading…").font(.caption).foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .task { await loadLatest() }
    }

    private func loadLatest() async {
        guard !didLoad, let api = session.api else { return }
        latest = try? await api.pipelines(projectId: project.id, page: 1).items.first
        didLoad = true
    }
}
