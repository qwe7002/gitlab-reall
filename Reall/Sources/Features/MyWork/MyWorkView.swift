import SwiftUI

struct MyWorkView: View {
    enum Kind: String, CaseIterable, Identifiable {
        case issues = "Issues"
        case mergeRequests = "Merge Requests"
        var id: String { rawValue }
    }

    @Environment(AppSession.self) private var session
    @State private var kind: Kind = .issues
    @State private var showOpen = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Type", selection: $kind) {
                    ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                switch kind {
                case .issues:
                    MyIssuesList(showOpen: showOpen)
                        .id("issues-\(showOpen)")
                case .mergeRequests:
                    MyMergeRequestsList(showOpen: showOpen)
                        .id("mrs-\(showOpen)")
                }
            }
            .navigationTitle("My Work")
            .navigationDestination(for: Route.self) { $0.destination }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("State", selection: $showOpen) {
                        Label("Open", systemImage: "circle").tag(true)
                        Label("Closed", systemImage: "checkmark.circle").tag(false)
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }
}

private struct MyIssuesList: View {
    @Environment(AppSession.self) private var session
    let showOpen: Bool
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
        .task {
            guard loader == nil, let api = session.api else { return }
            let state = showOpen ? "opened" : "closed"
            let l = PaginatedLoader<GitLabIssue> { try await api.myIssues(state: state, page: $0) }
            loader = l
            await l.loadFirstIfNeeded()
        }
    }
}

private struct MyMergeRequestsList: View {
    @Environment(AppSession.self) private var session
    let showOpen: Bool
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
        .task {
            guard loader == nil, let api = session.api else { return }
            let state = showOpen ? "opened" : "closed"
            let l = PaginatedLoader<GitLabMergeRequest> { try await api.myMergeRequests(state: state, page: $0) }
            loader = l
            await l.loadFirstIfNeeded()
        }
    }
}
