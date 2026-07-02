import SwiftUI

/// A searchable list of the signed-in user's projects. Assigns the tapped
/// project to `selection` and pops back. Reusable wherever a project has to be
/// chosen (e.g. creating an issue).
struct ProjectPickerView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: GitLabProject?

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
                    Button {
                        selection = project
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            ProjectRow(project: project)
                            if project.id == selection?.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Select Project")
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
