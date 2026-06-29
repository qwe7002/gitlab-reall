import Foundation

/// A GitLab issue.
/// https://docs.gitlab.com/ee/api/issues.html
struct GitLabIssue: Codable, Identifiable, Hashable {
    let id: Int
    let iid: Int
    let projectId: Int
    let title: String
    let description: String?
    let state: String          // "opened" | "closed"
    let createdAt: Date?
    let updatedAt: Date?
    let closedAt: Date?
    let labels: [String]
    let author: GitLabUser?
    let assignees: [GitLabUser]?
    let milestone: GitLabMilestone?
    let userNotesCount: Int?
    let upvotes: Int?
    let downvotes: Int?
    let webURL: URL?
    let references: GitLabReferences?

    enum CodingKeys: String, CodingKey {
        case id, iid, title, description, state, labels, author, assignees, milestone, upvotes, downvotes, references
        case projectId = "project_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case closedAt = "closed_at"
        case userNotesCount = "user_notes_count"
        case webURL = "web_url"
    }
}

extension GitLabIssue {
    var isOpen: Bool { state == "opened" }
    /// e.g. "group/project#42"
    var reference: String { references?.full ?? "#\(iid)" }
}

struct GitLabReferences: Codable, Hashable {
    let short: String?
    let relative: String?
    let full: String?
}

struct GitLabMilestone: Codable, Identifiable, Hashable {
    let id: Int
    let iid: Int?
    let title: String
    let state: String?
    let dueDate: String?

    enum CodingKeys: String, CodingKey {
        case id, iid, title, state
        case dueDate = "due_date"
    }
}
