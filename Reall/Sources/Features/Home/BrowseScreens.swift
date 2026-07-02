import SwiftUI

/// The projects the signed-in user is a member of, with search.
struct ProjectsScreen: View {
    @Environment(AppSession.self) private var session
    @State private var loader: PaginatedLoader<GitLabProject>?
    @State private var query = ""
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let loader {
                PagedListView(
                    loader: loader,
                    emptyTitle: query.isEmpty ? "No projects" : "No results",
                    emptyMessage: "Projects you're a member of appear here.",
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
        .searchable(text: $query, prompt: "Search your projects")
        .onChange(of: query) { _, newValue in scheduleSearch(newValue) }
        .task {
            guard loader == nil, let api = session.api else { return }
            let l = PaginatedLoader<GitLabProject> { try await api.myProjects(page: $0) }
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
            let l = PaginatedLoader<GitLabProject> {
                try await api.myProjects(page: $0, search: trimmed.isEmpty ? nil : trimmed)
            }
            loader = l
            await l.loadFirstIfNeeded()
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
        .task {
            guard loader == nil, let api = session.api else { return }
            let l = PaginatedLoader<GitLabProject> { try await api.groupProjects(groupId: group.id, page: $0) }
            loader = l
            await l.loadFirstIfNeeded()
        }
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
