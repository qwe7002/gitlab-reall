import SwiftUI

struct IssueDetailView: View {
    @Environment(AppSession.self) private var session
    let issue: GitLabIssue

    @State private var notes: [GitLabNote] = []
    @State private var isLoadingNotes = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                Divider()
                if let description = issue.description, !description.isEmpty {
                    CommentBubble(author: issue.author,
                                  date: issue.createdAt,
                                  body: description)
                }
                commentsSection
            }
            .padding()
        }
        .navigationTitle(issue.reference)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let url = issue.webURL {
                ToolbarItem(placement: .topBarTrailing) {
                    Link(destination: url) { Image(systemName: "safari") }
                }
            }
        }
        .task { await loadNotes() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(issue.title).font(.title3.bold())
            HStack {
                StatusBadge(issue.isOpen ? "Open" : "Closed",
                            systemImage: issue.isOpen ? "exclamationmark.circle" : "checkmark.circle.fill",
                            color: Theme.issueColor(open: issue.isOpen))
                if let author = issue.author {
                    Text("opened by \(author.username)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            LabelFlow(labels: issue.labels)
        }
    }

    @ViewBuilder
    private var commentsSection: some View {
        if isLoadingNotes {
            ProgressView().frame(maxWidth: .infinity)
        } else {
            let visible = notes.filter { !$0.isSystem }
            if !visible.isEmpty {
                Text("\(visible.count) comments")
                    .font(.headline)
                ForEach(visible) { note in
                    CommentBubble(author: note.author, date: note.createdAt, body: note.body)
                }
            }
        }
    }

    private func loadNotes() async {
        guard let api = session.api else { return }
        isLoadingNotes = true
        defer { isLoadingNotes = false }
        notes = (try? await api.issueNotes(projectId: issue.projectId, issueIID: issue.iid).items) ?? []
    }
}

/// A GitHub-style comment card.
struct CommentBubble: View {
    let author: GitLabUser?
    let date: Date?
    let markdown: String

    init(author: GitLabUser?, date: Date?, body: String) {
        self.author = author
        self.date = date
        self.markdown = body
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AvatarView(url: author?.avatarURL, fallbackText: author?.displayName ?? "?", size: 28)
                Text(author?.displayName ?? "Unknown").font(.subheadline.weight(.semibold))
                Spacer()
                RelativeDateText(date: date).font(.caption).foregroundStyle(.secondary)
            }
            MarkdownText(markdown)
                .font(.subheadline)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Renders a markdown string, falling back to plain text on parse failure.
struct MarkdownText: View {
    let raw: String
    init(_ raw: String) { self.raw = raw }

    var body: some View {
        if let attributed = try? AttributedString(
            markdown: raw,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
        } else {
            Text(raw)
        }
    }
}
