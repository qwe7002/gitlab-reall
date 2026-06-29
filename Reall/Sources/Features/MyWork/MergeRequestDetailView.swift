import SwiftUI

struct MergeRequestDetailView: View {
    @Environment(AppSession.self) private var session
    let mr: GitLabMergeRequest

    @State private var notes: [GitLabNote] = []
    @State private var isLoadingNotes = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                Divider()
                if let description = mr.description, !description.isEmpty {
                    CommentBubble(author: mr.author, date: mr.createdAt, body: description)
                }
                commentsSection
            }
            .padding()
        }
        .navigationTitle(mr.reference)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let url = mr.webURL {
                ToolbarItem(placement: .topBarTrailing) {
                    Link(destination: url) { Image(systemName: "safari") }
                }
            }
        }
        .task { await loadNotes() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(mr.title).font(.title3.bold())
            HStack {
                StatusBadge(stateLabel, systemImage: "arrow.triangle.pull", color: Theme.mrColor(mr.displayState))
                if let author = mr.author {
                    Text("by \(author.username)").font(.caption).foregroundStyle(.secondary)
                }
            }
            if let source = mr.sourceBranch, let target = mr.targetBranch {
                Label("\(source) → \(target)", systemImage: "arrow.triangle.branch")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            if mr.hasConflicts == true {
                Label("This merge request has conflicts", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            LabelFlow(labels: mr.labels)
        }
    }

    private var stateLabel: String {
        switch mr.displayState {
        case .open: return "Open"
        case .draft: return "Draft"
        case .merged: return "Merged"
        case .closed: return "Closed"
        }
    }

    @ViewBuilder
    private var commentsSection: some View {
        if isLoadingNotes {
            ProgressView().frame(maxWidth: .infinity)
        } else {
            let visible = notes.filter { !$0.isSystem }
            if !visible.isEmpty {
                Text("\(visible.count) comments").font(.headline)
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
        notes = (try? await api.mergeRequestNotes(projectId: mr.projectId, mrIID: mr.iid).items) ?? []
    }
}
