import SwiftUI

/// The signed-in user's projects, filterable by scope and searchable.
struct ProjectsScreen: View {
    enum Scope: String, CaseIterable, Identifiable {
        case member = "Member"
        case owned = "Owned"
        case starred = "Starred"
        var id: String { rawValue }
        var apiValue: String {
            switch self {
            case .member: return "member"
            case .owned: return "owned"
            case .starred: return "starred"
            }
        }
    }

    @Environment(AppSession.self) private var session
    @State private var loader: PaginatedLoader<GitLabProject>?
    @State private var scope: Scope = .member
    @State private var query = ""
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let loader {
                PagedListView(
                    loader: loader,
                    emptyTitle: query.isEmpty ? "No projects" : "No results",
                    emptyMessage: emptyMessage,
                    emptyImage: "folder"
                ) { project in
                    NavigationLink(value: Route.project(project)) {
                        ProjectRow(project: project)
                    }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Projects")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Scope", selection: $scope) {
                    ForEach(Scope.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
            }
        }
        .searchable(text: $query, prompt: "Search projects")
        .onChange(of: query) { _, _ in scheduleReload() }
        .task(id: scope) { await reload() }
    }

    private var emptyMessage: String {
        switch scope {
        case .member: return "Projects you're a member of appear here."
        case .owned: return "Projects you own appear here."
        case .starred: return "Projects you've starred appear here."
        }
    }

    private func reload() async {
        guard let api = session.api else { return }
        let term = query.trimmingCharacters(in: .whitespaces)
        let currentScope = scope.apiValue
        let l = PaginatedLoader<GitLabProject> {
            try await api.projects(scope: currentScope, search: term.isEmpty ? nil : term, page: $0)
        }
        loader = l
        await l.loadFirstIfNeeded()
    }

    private func scheduleReload() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await reload()
        }
    }
}

/// The groups the signed-in user belongs to.
struct GroupsScreen: View {
    @Environment(AppSession.self) private var session
    @State private var loader: PaginatedLoader<GitLabGroup>?
    @State private var query = ""
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let loader {
                PagedListView(
                    loader: loader,
                    emptyTitle: query.isEmpty ? "No groups" : "No results",
                    emptyMessage: "Groups you belong to appear here.",
                    emptyImage: "person.3"
                ) { group in
                    NavigationLink {
                        GroupDetailView(group: group)
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
        .searchable(text: $query, prompt: "Search groups")
        .onChange(of: query) { _, newValue in scheduleSearch(newValue) }
        .task {
            guard loader == nil, let api = session.api else { return }
            let l = PaginatedLoader<GitLabGroup> { try await api.groups(page: $0) }
            loader = l
            await l.loadFirstIfNeeded()
        }
    }

    private func scheduleSearch(_ term: String) {
        searchTask?.cancel()
        guard let api = session.api else { return }
        let trimmed = term.trimmingCharacters(in: .whitespaces)
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            let l = PaginatedLoader<GitLabGroup> {
                try await api.groups(page: $0, search: trimmed.isEmpty ? nil : trimmed)
            }
            loader = l
            await l.loadFirstIfNeeded()
        }
    }
}

struct GroupRow: View {
    let group: GitLabGroup

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(url: group.avatarURL, fallbackText: group.name, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(group.fullPath ?? group.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}

/// A group's overview plus the projects it contains.
struct GroupDetailView: View {
    @Environment(AppSession.self) private var session
    let group: GitLabGroup
    @State private var loader: PaginatedLoader<GitLabProject>?
    @State private var showingNewProject = false

    var body: some View {
        List {
            Section {
                header
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 8, trailing: 20))
            }

            Section("Projects") {
                projectsSection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNewProject = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New project in group")
            }
            if let url = group.webURL {
                ToolbarItem(placement: .topBarTrailing) {
                    Link(destination: url) { Image(systemName: "safari") }
                }
            }
        }
        .sheet(isPresented: $showingNewProject) {
            NavigationStack {
                NewProjectView(group: group) { _ in
                    Task { await reload() }
                }
            }
        }
        .task {
            guard loader == nil else { return }
            await reload()
        }
    }

    private func reload() async {
        guard let api = session.api else { return }
        let l = PaginatedLoader<GitLabProject> { try await api.groupProjects(groupId: group.id, page: $0) }
        loader = l
        await l.loadFirstIfNeeded()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                AvatarView(url: group.avatarURL, fallbackText: group.name, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name).font(.title3.bold())
                    Text(group.fullPath ?? group.path)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if let description = group.description, !description.isEmpty {
                Text(description).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var projectsSection: some View {
        if let loader {
            if loader.items.isEmpty {
                switch loader.phase {
                case .idle, .loading:
                    ProgressView().frame(maxWidth: .infinity)
                case .failed(let message):
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                case .loaded:
                    Text("No projects in this group.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                ForEach(loader.items) { project in
                    NavigationLink(value: Route.project(project)) {
                        ProjectRow(project: project)
                    }
                    .task { await loader.loadMoreIfNeeded(currentItem: project) }
                }
                if loader.isLoadingMore {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
        } else {
            ProgressView().frame(maxWidth: .infinity)
        }
    }
}
