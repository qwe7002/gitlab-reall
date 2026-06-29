import SwiftUI

struct IssueRow: View {
    let issue: GitLabIssue
    var showProjectRef: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: issue.isOpen ? "exclamationmark.circle" : "checkmark.circle.fill")
                .foregroundStyle(Theme.issueColor(open: issue.isOpen))
                .font(.title3)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                Text(issue.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                LabelFlow(labels: issue.labels)
                HStack(spacing: 8) {
                    Text(showProjectRef ? issue.reference : "#\(issue.iid)")
                    RelativeDateText(date: issue.updatedAt, prefix: "updated ")
                    if let count = issue.userNotesCount, count > 0 {
                        Label("\(count)", systemImage: "text.bubble")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MergeRequestRow: View {
    let mr: GitLabMergeRequest
    var showProjectRef: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.mrColor(mr.displayState))
                .font(.title3)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                Text(mr.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                LabelFlow(labels: mr.labels)
                HStack(spacing: 8) {
                    Text(showProjectRef ? mr.reference : "!\(mr.iid)")
                    if let source = mr.sourceBranch, let target = mr.targetBranch {
                        Label("\(source) → \(target)", systemImage: "arrow.triangle.branch")
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var symbol: String {
        switch mr.displayState {
        case .open: return "arrow.triangle.pull"
        case .draft: return "pencil.circle"
        case .merged: return "arrow.triangle.merge"
        case .closed: return "xmark.circle"
        }
    }
}

struct ProjectRow: View {
    let project: GitLabProject

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(url: project.avatarURL,
                       fallbackText: project.name,
                       size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(project.nameWithNamespace)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if let description = project.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 12) {
                    Label("\(project.starCount)", systemImage: "star")
                    Label("\(project.forksCount)", systemImage: "tuningfork")
                    if let visibility = project.visibility {
                        Label(visibility.capitalized, systemImage: visibility == "private" ? "lock" : "globe")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
