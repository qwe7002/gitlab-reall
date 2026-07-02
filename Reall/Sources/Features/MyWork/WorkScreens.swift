import SwiftUI

/// Issues assigned to the signed-in user. Pushed from Home; relies on the
/// enclosing navigation stack for its `Route` destinations.
struct MyIssuesScreen: View {
    @Environment(AppSession.self) private var session
    @State private var showOpen = true
    @State private var loader: PaginatedLoader<GitLabIssue>?

    var body: some View {
        Group {
            if let loader {
                PagedListView(
                    loader: loader,
                    emptyTitle: "No issues",
                    emptyMessage: "Issues assigned to you appear here.",
                    emptyImage: "checkmark.seal"
                ) { issue in
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
        .toolbar { StateFilterToolbar(showOpen: $showOpen) }
        .task(id: showOpen) {
            guard let api = session.api else { return }
            let state = showOpen ? "opened" : "closed"
            let l = PaginatedLoader<GitLabIssue> { try await api.myIssues(state: state, page: $0) }
            loader = l
            await l.loadFirstIfNeeded()
        }
    }
}

/// Merge requests assigned to the signed-in user.
struct MyMergeRequestsScreen: View {
    @Environment(AppSession.self) private var session
    @State private var showOpen = true
    @State private var loader: PaginatedLoader<GitLabMergeRequest>?

    var body: some View {
        Group {
            if let loader {
                PagedListView(
                    loader: loader,
                    emptyTitle: "No merge requests",
                    emptyMessage: "Merge requests assigned to you appear here.",
                    emptyImage: "arrow.triangle.merge"
                ) { mr in
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
        .toolbar { StateFilterToolbar(showOpen: $showOpen) }
        .task(id: showOpen) {
            guard let api = session.api else { return }
            let state = showOpen ? "opened" : "closed"
            let l = PaginatedLoader<GitLabMergeRequest> { try await api.myMergeRequests(state: state, page: $0) }
            loader = l
            await l.loadFirstIfNeeded()
        }
    }
}

/// Open / Closed menu shared by the assigned-work screens.
private struct StateFilterToolbar: ToolbarContent {
    @Binding var showOpen: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Picker("State", selection: $showOpen) {
                Label("Open", systemImage: "circle").tag(true)
                Label("Closed", systemImage: "checkmark.circle").tag(false)
            }
            .pickerStyle(.menu)
        }
    }
}
