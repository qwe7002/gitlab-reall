import Foundation

/// A GitLab merge request.
/// https://docs.gitlab.com/ee/api/merge_requests.html
struct GitLabMergeRequest: Codable, Identifiable, Hashable {
    let id: Int
    let iid: Int
    let projectId: Int
    let title: String
    let description: String?
    let state: String          // "opened" | "closed" | "merged" | "locked"
    let createdAt: Date?
    let updatedAt: Date?
    let mergedAt: Date?
    let closedAt: Date?
    let sourceBranch: String?
    let targetBranch: String?
    let draft: Bool?
    let workInProgress: Bool?
    let labels: [String]
    let author: GitLabUser?
    let assignees: [GitLabUser]?
    let reviewers: [GitLabUser]?
    let milestone: GitLabMilestone?
    let userNotesCount: Int?
    let upvotes: Int?
    let downvotes: Int?
    let mergeStatus: String?
    let hasConflicts: Bool?
    let webURL: URL?
    let references: GitLabReferences?

    enum CodingKeys: String, CodingKey {
        case id, iid, title, description, state, draft, labels, author, assignees, reviewers
        case milestone, upvotes, downvotes, references
        case projectId = "project_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case mergedAt = "merged_at"
        case closedAt = "closed_at"
        case sourceBranch = "source_branch"
        case targetBranch = "target_branch"
        case workInProgress = "work_in_progress"
        case userNotesCount = "user_notes_count"
        case mergeStatus = "merge_status"
        case hasConflicts = "has_conflicts"
        case webURL = "web_url"
    }
}

extension GitLabMergeRequest {
    enum DisplayState {
        case open, draft, merged, closed
    }

    var displayState: DisplayState {
        if state == "merged" { return .merged }
        if state == "closed" || state == "locked" { return .closed }
        if (draft ?? false) || (workInProgress ?? false) { return .draft }
        return .open
    }

    var reference: String { references?.full ?? "!\(iid)" }
}
