import SwiftUI

struct IssueDetailView: View {
    @Environment(AppSession.self) private var session
    let issue: GitLabIssue

    @State private var currentIssue: GitLabIssue
    @State private var notes: [GitLabNote] = []
    @State private var isLoadingNotes = true
    @State private var isChangingState = false
    @State private var isPostingComment = false
    @State private var commentText = ""
    @State private var errorMessage: String?

    init(issue: GitLabIssue) {
        self.issue = issue
        _currentIssue = State(initialValue: issue)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                metadata
                Divider()
                if let description = currentIssue.description, !description.isEmpty {
                    CommentBubble(author: currentIssue.author,
                                  date: currentIssue.createdAt,
                                  body: description)
                }
                commentComposer
                commentsSection
            }
            .padding()
        }
        .navigationTitle(currentIssue.reference)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Task { await refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoadingNotes || isPostingComment || isChangingState)

                Button {
                    Task { await toggleIssueState() }
                } label: {
                    Image(systemName: currentIssue.isOpen ? "checkmark.circle" : "arrow.uturn.backward.circle")
                }
                .disabled(isChangingState)

                if let url = currentIssue.webURL {
                    Link(destination: url) { Image(systemName: "safari") }
                }
            }
        }
        .alert("Issue action failed", isPresented: errorBinding) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Something went wrong.")
        }
        .task { await loadNotes() }
        .refreshable { await refresh() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(currentIssue.title).font(.title3.bold())
            HStack {
                StatusBadge(currentIssue.isOpen ? "Open" : "Closed",
                            systemImage: currentIssue.isOpen ? "exclamationmark.circle" : "checkmark.circle.fill",
                            color: Theme.issueColor(open: currentIssue.isOpen))
                if let author = currentIssue.author {
                    Text("opened by \(author.username)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            LabelFlow(labels: currentIssue.labels)
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let assignees = currentIssue.assignees, !assignees.isEmpty {
                Label(assignees.map(\.displayName).joined(separator: ", "), systemImage: "person.crop.circle")
            }
            if let milestone = currentIssue.milestone {
                Label(milestone.title, systemImage: "flag")
            }
            HStack(spacing: 12) {
                if let updatedAt = currentIssue.updatedAt {
                    Label {
                        RelativeDateText(date: updatedAt, prefix: "updated ")
                    } icon: {
                        Image(systemName: "clock")
                    }
                }
                if let count = currentIssue.userNotesCount {
                    Label("\(count)", systemImage: "text.bubble")
                }
                if let upvotes = currentIssue.upvotes, upvotes > 0 {
                    Label("\(upvotes)", systemImage: "hand.thumbsup")
                }
                if let downvotes = currentIssue.downvotes, downvotes > 0 {
                    Label("\(downvotes)", systemImage: "hand.thumbsdown")
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var commentComposer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add comment")
                .font(.headline)
            TextEditor(text: $commentText)
                .frame(minHeight: 96)
                .padding(8)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(.separator), lineWidth: 0.5))
            HStack {
                Spacer()
                Button {
                    Task { await postComment() }
                } label: {
                    if isPostingComment {
                        ProgressView()
                    } else {
                        Label("Comment", systemImage: "paperplane.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPostingComment)
            }
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
            } else {
                Text("No comments yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func refresh() async {
        await loadNotes()
    }

    private func loadNotes() async {
        guard let api = session.api else { return }
        isLoadingNotes = true
        defer { isLoadingNotes = false }
        do {
            notes = try await api.issueNotes(projectId: currentIssue.projectId, issueIID: currentIssue.iid).items
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func postComment() async {
        let body = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, let api = session.api else { return }
        isPostingComment = true
        defer { isPostingComment = false }
        do {
            let note = try await api.createIssueNote(projectId: currentIssue.projectId, issueIID: currentIssue.iid, body: body)
            notes.append(note)
            commentText = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleIssueState() async {
        guard let api = session.api else { return }
        isChangingState = true
        defer { isChangingState = false }
        do {
            let event: IssueStateEvent = currentIssue.isOpen ? .close : .reopen
            currentIssue = try await api.updateIssueState(projectId: currentIssue.projectId,
                                                          issueIID: currentIssue.iid,
                                                          stateEvent: event)
        } catch {
            errorMessage = error.localizedDescription
        }
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
            MarkdownView(markdown)
                .font(.subheadline)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
