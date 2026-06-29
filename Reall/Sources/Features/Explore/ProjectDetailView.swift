import SwiftUI

struct ProjectDetailView: View {
    @Environment(AppSession.self) private var session
    let project: GitLabProject

    @State private var readme: String?
    @State private var loadingReadme = true

    @State private var hookInstalled: Bool?
    @State private var hookBusy = false

    var body: some View {
        List {
            Section { headerCard }

            if session.pushManager.webhookSecret != nil {
                Section {
                    Toggle(isOn: hookToggleBinding) {
                        Label("Push notifications", systemImage: "bell.badge")
                    }
                    .disabled(hookBusy || hookInstalled == nil)
                } footer: {
                    Text("Installs a GitLab webhook on this project so you get CI and review pushes for it.")
                }
            }

            Section {
                NavigationLink(value: Route.pipelines(project)) {
                    Label("Pipelines", systemImage: "bolt.horizontal.fill")
                }
                NavigationLink {
                    ProjectIssuesView(project: project)
                } label: {
                    Label {
                        HStack {
                            Text("Issues")
                            Spacer()
                            if let count = project.openIssuesCount {
                                Text("\(count)").foregroundStyle(.secondary)
                            }
                        }
                    } icon: { Image(systemName: "exclamationmark.circle.fill") }
                }
                NavigationLink {
                    ProjectMergeRequestsView(project: project)
                } label: {
                    Label("Merge Requests", systemImage: "arrow.triangle.pull")
                }
                if let url = project.webURL {
                    Link(destination: url) {
                        Label("Open in browser", systemImage: "safari")
                    }
                }
            }

            if loadingReadme {
                Section { ProgressView().frame(maxWidth: .infinity) }
            } else if let readme, !readme.isEmpty {
                Section("README") {
                    MarkdownText(readme).font(.subheadline).padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadReadme() }
        .task { await loadHookState() }
    }

    private var hookToggleBinding: Binding<Bool> {
        Binding(
            get: { hookInstalled ?? false },
            set: { newValue in Task { await setHook(newValue) } }
        )
    }

    private func loadHookState() async {
        guard let api = session.api, let service = session.pushManager.webhookService(api: api) else { return }
        hookInstalled = await service.isInstalled(projectId: project.id)
    }

    private func setHook(_ enabled: Bool) async {
        guard let api = session.api, let service = session.pushManager.webhookService(api: api) else { return }
        hookBusy = true
        defer { hookBusy = false }
        do {
            if enabled {
                try await service.ensureHook(projectId: project.id)
                hookInstalled = true
            } else {
                try await service.removeHook(projectId: project.id)
                hookInstalled = false
            }
        } catch {
            // Revert the toggle on failure (e.g. insufficient permission).
            hookInstalled = !enabled
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                AvatarView(url: project.avatarURL, fallbackText: project.name, size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.nameWithNamespace).font(.headline)
                    if let visibility = project.visibility {
                        Label(visibility.capitalized,
                              systemImage: visibility == "private" ? "lock.fill" : "globe")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if let description = project.description, !description.isEmpty {
                Text(description).font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(spacing: 20) {
                statItem(value: project.starCount, label: "Stars", symbol: "star.fill")
                statItem(value: project.forksCount, label: "Forks", symbol: "tuningfork")
                if let issues = project.openIssuesCount {
                    statItem(value: issues, label: "Issues", symbol: "exclamationmark.circle.fill")
                }
            }
            if let topics = project.topics, !topics.isEmpty {
                LabelFlow(labels: topics)
            }
        }
        .padding(.vertical, 4)
    }

    private func statItem(value: Int, label: String, symbol: String) -> some View {
        VStack(spacing: 2) {
            Label("\(value)", systemImage: symbol).font(.subheadline.weight(.semibold))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func loadReadme() async {
        guard let api = session.api else { return }
        loadingReadme = true
        defer { loadingReadme = false }
        let ref = project.defaultBranch ?? "main"
        if let file = try? await api.readme(projectId: project.id, ref: ref) {
            readme = file.decodedText
        }
    }
}

/// Issues scoped to a single project.
struct ProjectIssuesView: View {
    @Environment(AppSession.self) private var session
    let project: GitLabProject
    @State private var loader: PaginatedLoader<GitLabIssue>?

    var body: some View {
        Group {
            if let loader {
                PagedListView(loader: loader, emptyTitle: "No open issues", emptyImage: "checkmark.seal") { issue in
                    NavigationLink(value: Route.issue(issue)) { IssueRow(issue: issue) }
                }
            } else { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
        }
        .navigationTitle("Issues")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard loader == nil, let api = session.api else { return }
            let l = PaginatedLoader<GitLabIssue> { try await api.issues(projectId: project.id, page: $0) }
            loader = l
            await l.loadFirstIfNeeded()
        }
    }
}

/// Merge requests scoped to a single project.
struct ProjectMergeRequestsView: View {
    @Environment(AppSession.self) private var session
    let project: GitLabProject
    @State private var loader: PaginatedLoader<GitLabMergeRequest>?

    var body: some View {
        Group {
            if let loader {
                PagedListView(loader: loader, emptyTitle: "No open merge requests", emptyImage: "arrow.triangle.merge") { mr in
                    NavigationLink(value: Route.mergeRequest(mr)) { MergeRequestRow(mr: mr) }
                }
            } else { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
        }
        .navigationTitle("Merge Requests")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard loader == nil, let api = session.api else { return }
            let l = PaginatedLoader<GitLabMergeRequest> { try await api.mergeRequests(projectId: project.id, page: $0) }
            loader = l
            await l.loadFirstIfNeeded()
        }
    }
}
