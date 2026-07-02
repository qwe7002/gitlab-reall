import SwiftUI

struct HomeView: View {
    @Environment(AppSession.self) private var session
    @State private var loader: PaginatedLoader<GitLabEvent>?
    @State private var showingProfile = false
    @State private var createSheet: HomeCreateSheet?

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
                    NavigationLink { SnippetsScreen() } label: {
                        DashboardLabel("Snippets", systemImage: "curlybraces", color: .purple)
                    }
                    NavigationLink { ProjectsScreen() } label: {
                        DashboardLabel("Projects", systemImage: "folder.fill", color: .indigo)
                    }
                    NavigationLink { GroupsScreen() } label: {
                        DashboardLabel("Groups", systemImage: "person.3.fill", color: .teal)
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
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { createSheet = .issue } label: {
                            Label("New Issue", systemImage: "smallcircle.filled.circle")
                        }
                        Button { createSheet = .project } label: {
                            Label("New Project", systemImage: "folder.badge.plus")
                        }
                        Button { createSheet = .group } label: {
                            Label("New Group", systemImage: "person.3.fill")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create")
                }
            }
            .refreshable { await loader?.reload() }
            .sheet(isPresented: $showingProfile) { ProfileView() }
            .sheet(item: $createSheet) { sheet in
                NavigationStack {
                    switch sheet {
                    case .issue:
                        NewIssueView()
                    case .project:
                        NewProjectView()
                    case .group:
                        NewGroupView()
                    }
                }
            }
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
                ForEach(Array(loader.items.prefix(5))) { event in
                    EventRow(event: event, host: session.api?.host)
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

private enum HomeCreateSheet: String, Identifiable {
    case issue, project, group
    var id: String { rawValue }
}

struct MyIssuesScreen: View {
    @Environment(AppSession.self) private var session
    @State private var loader: PaginatedLoader<GitLabIssue>?

    var body: some View {
        Group {
            if let loader {
                PagedListView(loader: loader, emptyTitle: "No assigned issues", emptyImage: "checkmark.seal") { issue in
                    NavigationLink(value: Route.issue(issue)) {
                        IssueRow(issue: issue, showProjectRef: true)
                    }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Issues")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard loader == nil, let api = session.api else { return }
            let l = PaginatedLoader<GitLabIssue> { try await api.myIssues(page: $0) }
            loader = l
            await l.loadFirstIfNeeded()
        }
    }
}

struct MyMergeRequestsScreen: View {
    @Environment(AppSession.self) private var session
    @State private var loader: PaginatedLoader<GitLabMergeRequest>?

    var body: some View {
        Group {
            if let loader {
                PagedListView(loader: loader, emptyTitle: "No assigned merge requests", emptyImage: "arrow.triangle.merge") { mr in
                    NavigationLink(value: Route.mergeRequest(mr)) {
                        MergeRequestRow(mr: mr, showProjectRef: true)
                    }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Merge Requests")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard loader == nil, let api = session.api else { return }
            let l = PaginatedLoader<GitLabMergeRequest> { try await api.myMergeRequests(page: $0) }
            loader = l
            await l.loadFirstIfNeeded()
        }
    }
}

struct ProjectsScreen: View {
    @Environment(AppSession.self) private var session
    @State private var loader: PaginatedLoader<GitLabProject>?

    var body: some View {
        Group {
            if let loader {
                PagedListView(loader: loader,
                              emptyTitle: "No projects",
                              emptyMessage: "Projects you're a member of will appear here.",
                              emptyImage: "folder") { project in
                    NavigationLink {
                        ProjectDetailView(project: project)
                    } label: {
                        ProjectRow(project: project)
                    }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Projects")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard loader == nil, let api = session.api else { return }
            let l = PaginatedLoader<GitLabProject> { try await api.myProjects(page: $0) }
            loader = l
            await l.loadFirstIfNeeded()
        }
    }
}

struct GroupsScreen: View {
    @Environment(AppSession.self) private var session
    @State private var loader: PaginatedLoader<GitLabGroup>?

    var body: some View {
        Group {
            if let loader {
                PagedListView(loader: loader,
                              emptyTitle: "No groups",
                              emptyMessage: "Groups you can access will appear here.",
                              emptyImage: "person.3") { group in
                    NavigationLink {
                        GroupProjectsScreen(group: group)
                    } label: {
                        GroupRow(group: group)
                    }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Groups")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard loader == nil, let api = session.api else { return }
            let l = PaginatedLoader<GitLabGroup> { try await api.groups(page: $0) }
            loader = l
            await l.loadFirstIfNeeded()
        }
    }
}

struct GroupProjectsScreen: View {
    @Environment(AppSession.self) private var session
    let group: GitLabGroup
    @State private var loader: PaginatedLoader<GitLabProject>?

    var body: some View {
        Group {
            if let loader {
                PagedListView(loader: loader,
                              emptyTitle: "No projects",
                              emptyMessage: "Projects in this group will appear here.",
                              emptyImage: "folder") { project in
                    NavigationLink {
                        ProjectDetailView(project: project)
                    } label: {
                        ProjectRow(project: project)
                    }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let url = group.webURL {
                ToolbarItem(placement: .topBarTrailing) {
                    Link(destination: url) { Image(systemName: "safari") }
                }
            }
        }
        .task {
            guard loader == nil, let api = session.api else { return }
            let l = PaginatedLoader<GitLabProject> { try await api.groupProjects(groupId: group.id, page: $0) }
            loader = l
            await l.loadFirstIfNeeded()
        }
    }
}

struct GroupRow: View {
    let group: GitLabGroup

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(url: group.avatarURL,
                       fallbackText: group.name,
                       size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(group.fullPath ?? group.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if let description = group.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if let visibility = group.visibility {
                    Label(visibility.capitalized, systemImage: visibility == "private" ? "lock" : "globe")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct SnippetsScreen: View {
    @Environment(AppSession.self) private var session
    @State private var loader: PaginatedLoader<GitLabSnippet>?

    var body: some View {
        Group {
            if let loader {
                PagedListView(loader: loader,
                              emptyTitle: "No snippets",
                              emptyMessage: "Snippets you can access will appear here.",
                              emptyImage: "curlybraces") { snippet in
                    NavigationLink {
                        SnippetDetailView(snippet: snippet)
                    } label: {
                        SnippetRow(snippet: snippet)
                    }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Snippets")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard loader == nil, let api = session.api else { return }
            let l = PaginatedLoader<GitLabSnippet> { try await api.snippets(page: $0) }
            loader = l
            await l.loadFirstIfNeeded()
        }
    }
}

struct SnippetRow: View {
    let snippet: GitLabSnippet

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "curlybraces")
                .foregroundStyle(.purple)
                .font(.title3)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(snippet.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                if let description = snippet.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    if let fileName = snippet.fileName {
                        Text(fileName).monospaced()
                    }
                    if let updatedAt = snippet.updatedAt ?? snippet.createdAt {
                        RelativeDateText(date: updatedAt, prefix: "updated ")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SnippetDetailView: View {
    @Environment(AppSession.self) private var session
    let snippet: GitLabSnippet

    @State private var rawText: String?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(snippet.title)
                    .font(.title3.bold())
                if let description = snippet.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Divider()
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else if let rawText {
                    Text(rawText)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Snippet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let url = snippet.webURL {
                ToolbarItem(placement: .topBarTrailing) {
                    Link(destination: url) { Image(systemName: "safari") }
                }
            }
        }
        .task { await loadRawText() }
    }

    private func loadRawText() async {
        guard let api = session.api else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            rawText = try await api.snippetRaw(id: snippet.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct NewIssueView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    /// A project can be pre-selected (e.g. when creating from a project page).
    let initialProject: GitLabProject?

    @State private var projects: [GitLabProject] = []
    @State private var selectedProjectId: Int?
    @State private var loadingProjects = true
    @State private var title = ""
    @State private var description = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    init(project: GitLabProject? = nil) {
        self.initialProject = project
        _selectedProjectId = State(initialValue: project?.id)
    }

    var body: some View {
        Form {
            Section {
                projectPicker
                TextField("Title", text: $title)
                TextEditor(text: $description)
                    .frame(minHeight: 120)
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle("New Issue")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                if isCreating {
                    ProgressView()
                } else {
                    Button("Create") { Task { await create() } }
                        .disabled(!canSubmit)
                }
            }
        }
        .task { await loadProjects() }
    }

    @ViewBuilder
    private var projectPicker: some View {
        if loadingProjects && projects.isEmpty {
            HStack {
                Text("Project")
                Spacer()
                ProgressView()
            }
        } else if projects.isEmpty {
            Text("No projects available").foregroundStyle(.secondary)
        } else {
            Picker("Project", selection: $selectedProjectId) {
                Text("Select a project").tag(Int?.none)
                ForEach(projects) { project in
                    Text(project.nameWithNamespace).tag(Int?.some(project.id))
                }
            }
        }
    }

    private var canSubmit: Bool {
        selectedProjectId != nil
            && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isCreating
    }

    private func loadProjects() async {
        guard let api = session.api else { return }
        loadingProjects = true
        defer { loadingProjects = false }
        var loaded = (try? await api.myProjects(page: 1).items) ?? []
        // Make sure a pre-selected project is always present in the list.
        if let initialProject, !loaded.contains(where: { $0.id == initialProject.id }) {
            loaded.insert(initialProject, at: 0)
        }
        projects = loaded
    }

    private func create() async {
        guard let api = session.api, let id = selectedProjectId else { return }
        isCreating = true
        defer { isCreating = false }
        do {
            _ = try await api.createIssue(projectId: id,
                                          title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                          description: cleaned(description))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct NewProjectView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var path = ""
    @State private var description = ""
    @State private var visibility = "private"
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                TextField("Path", text: $path)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextEditor(text: $description)
                    .frame(minHeight: 96)
                Picker("Visibility", selection: $visibility) {
                    Text("Private").tag("private")
                    Text("Internal").tag("internal")
                    Text("Public").tag("public")
                }
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle("New Project")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") { Task { await create() } }
                    .disabled(!canSubmit)
            }
        }
        .onChange(of: name) { _, newValue in
            if path.isEmpty { path = suggestedPath(from: newValue) }
        }
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCreating
    }

    private func create() async {
        guard let api = session.api else { return }
        isCreating = true
        defer { isCreating = false }
        do {
            _ = try await api.createProject(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                            path: path.trimmingCharacters(in: .whitespacesAndNewlines),
                                            description: cleaned(description),
                                            visibility: visibility)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct NewGroupView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var path = ""
    @State private var description = ""
    @State private var visibility = "private"
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                TextField("Path", text: $path)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextEditor(text: $description)
                    .frame(minHeight: 96)
                Picker("Visibility", selection: $visibility) {
                    Text("Private").tag("private")
                    Text("Internal").tag("internal")
                    Text("Public").tag("public")
                }
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }
        }
        .navigationTitle("New Group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") { Task { await create() } }
                    .disabled(!canSubmit)
            }
        }
        .onChange(of: name) { _, newValue in
            if path.isEmpty { path = suggestedPath(from: newValue) }
        }
    }

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isCreating
    }

    private func create() async {
        guard let api = session.api else { return }
        isCreating = true
        defer { isCreating = false }
        do {
            _ = try await api.createGroup(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                          path: path.trimmingCharacters(in: .whitespacesAndNewlines),
                                          description: cleaned(description),
                                          visibility: visibility)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private func cleaned(_ text: String) -> String? {
    let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? nil : value
}

private func suggestedPath(from name: String) -> String {
    name.lowercased()
        .replacingOccurrences(of: " ", with: "-")
        .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == "." }
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
