import SwiftUI

/// GitHub-inbox style notification list backed by GitLab to-dos.
struct InboxView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case unread = "Unread"
        case all = "All"
        var id: String { rawValue }
        var apiState: String? { self == .unread ? "pending" : nil }
    }

    @Environment(AppSession.self) private var session
    @State private var filter: Filter = .unread
    @State private var loader: PaginatedLoader<GitLabTodo>?

    var body: some View {
        NavigationStack {
            Group {
                if let loader {
                    PagedListView(
                        loader: loader,
                        emptyTitle: filter == .unread ? "You're all caught up" : "Nothing in your inbox",
                        emptyMessage: "To-dos assigned to you on GitLab show up here.",
                        emptyImage: "tray"
                    ) { todo in
                        InboxRowLink(todo: todo)
                    }
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Inbox")
            .navigationDestination(for: Route.self) { $0.destination }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Filter", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                }
            }
        }
        .task(id: filter) { await load() }
    }

    private func load() async {
        guard let api = session.api else { return }
        let state = filter.apiState
        let l = PaginatedLoader<GitLabTodo> { try await api.todos(state: state, page: $0) }
        loader = l
        await l.loadFirstIfNeeded()
    }
}

/// A row that links into the underlying issue / merge request when one exists.
private struct InboxRowLink: View {
    let todo: GitLabTodo

    var body: some View {
        if let route = todo.route {
            NavigationLink(value: route) { InboxRow(todo: todo) }
        } else if let url = todo.targetURL {
            Link(destination: url) { InboxRow(todo: todo) }
        } else {
            InboxRow(todo: todo)
        }
    }
}

struct InboxRow: View {
    let todo: GitLabTodo

    private var iconColor: Color {
        if let mr = todo.mergeRequest { return Theme.mrColor(mr.displayState) }
        if let issue = todo.issue { return Theme.issueColor(open: issue.isOpen) }
        return .secondary
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 6) {
                Image(systemName: todo.iconName)
                    .font(.body)
                    .foregroundStyle(iconColor)
                if todo.isUnread {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                }
            }
            .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(todo.reference)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    RelativeDateText(date: todo.createdAt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .layoutPriority(1)
                }

                if let title = todo.title, !title.isEmpty {
                    Text(title)
                        .font(.headline)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    AvatarView(url: todo.author?.avatarURL,
                               fallbackText: todo.author?.displayName ?? "?",
                               size: 18)
                    Text(todo.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
