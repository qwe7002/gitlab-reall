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
            Section {
                header
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 8, trailing: 20))
            }

            Section {
                NavigationLink {
                    ProjectIssuesView(project: project)
                } label: {
                    navRow("Issues", systemImage: "smallcircle.filled.circle",
                           color: .green, count: project.openIssuesCount)
                }
                NavigationLink {
                    ProjectMergeRequestsView(project: project)
                } label: {
                    navRow("Merge Requests", systemImage: "arrow.triangle.pull", color: .blue)
                }
                NavigationLink(value: Route.pipelines(project)) {
                    navRow("Pipelines", systemImage: "play.circle.fill", color: .orange)
                }
            }

            if session.pushManager.webhookSecret != nil {
                Section {
                    Toggle(isOn: hookToggleBinding) {
                        navRow("Notifications", systemImage: "bell.fill", color: .red)
                    }
                    .disabled(hookBusy || hookInstalled == nil)
                } footer: {
                    Text("Installs a GitLab webhook on this project so you get CI and review pushes for it.")
                }
            }

            if loadingReadme {
                Section { ProgressView().frame(maxWidth: .infinity) }
            } else if let readme, !readme.isEmpty {
                Section("README") {
                    MarkdownView(readme).padding(.vertical, 4)
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                AvatarView(url: project.avatarURL, fallbackText: project.name, size: 24)
                Text(namespaceName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let visibility = project.visibility, visibility != "public" {
                    Image(systemName: visibility == "private" ? "lock.fill" : "eye.slash.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(project.name)
                .font(.largeTitle.bold())
                .lineLimit(2)

            if let description = project.description, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 20) {
                statInline(value: project.starCount, label: "stars", symbol: "star")
                statInline(value: project.forksCount, label: "forks", symbol: "arrow.triangle.branch")
            }
            .padding(.top, 2)

            if let topics = project.topics, !topics.isEmpty {
                LabelFlow(labels: topics)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The owner / group the project lives under.
    private var namespaceName: String {
        project.namespace?.name ?? project.nameWithNamespace
    }

    private func statInline(value: Int, label: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(.secondary)
            Text("\(value)").fontWeight(.semibold)
            Text(label).foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }

    /// A navigation row with a rounded colour-filled icon tile and optional count.
    private func navRow(_ title: String, systemImage: String, color: Color, count: Int? = nil) -> some View {
        HStack(spacing: 12) {
            DashboardLabel(title, systemImage: systemImage, color: color)
            Spacer(minLength: 8)
            if let count {
                Text("\(count)").foregroundStyle(.secondary)
            }
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
                PagedListView(loader: loader, emptyTitle: "No issues", emptyImage: "checkmark.seal") { issue in
                    NavigationLink {
                        IssueDetailView(issue: issue)
                    } label: {
                        IssueRow(issue: issue)
                    }
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
                    NavigationLink {
                        MergeRequestDetailView(mr: mr)
                    } label: {
                        MergeRequestRow(mr: mr)
                    }
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
