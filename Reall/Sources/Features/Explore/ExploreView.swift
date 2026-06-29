import SwiftUI

struct ExploreView: View {
    @Environment(AppSession.self) private var session

    @State private var query = ""
    @State private var loader: PaginatedLoader<GitLabProject>?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Group {
                if let loader {
                    PagedListView(
                        loader: loader,
                        emptyTitle: query.isEmpty ? "Explore GitLab" : "No results",
                        emptyMessage: query.isEmpty
                            ? "Search for projects across your GitLab instance."
                            : "No projects match “\(query)”.",
                        emptyImage: "magnifyingglass"
                    ) { project in
                        NavigationLink(value: Route.project(project)) {
                            ProjectRow(project: project)
                        }
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Explore")
            .navigationDestination(for: Route.self) { $0.destination }
            .searchable(text: $query, prompt: "Search projects")
            .onChange(of: query) { _, newValue in scheduleSearch(newValue) }
        }
        .task {
            guard loader == nil, let api = session.api else { return }
            // Default view: the projects you've starred.
            let l = PaginatedLoader<GitLabProject> { try await api.starredProjects(page: $0) }
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
            let l: PaginatedLoader<GitLabProject>
            if trimmed.isEmpty {
                l = PaginatedLoader { try await api.starredProjects(page: $0) }
            } else {
                l = PaginatedLoader { try await api.searchProjects(trimmed, page: $0) }
            }
            loader = l
            await l.loadFirstIfNeeded()
        }
    }
}
