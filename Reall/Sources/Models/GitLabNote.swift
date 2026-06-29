import Foundation

/// A note (comment) on an issue or merge request.
/// https://docs.gitlab.com/ee/api/notes.html
struct GitLabNote: Codable, Identifiable, Hashable {
    let id: Int
    let body: String
    let author: GitLabUser?
    let createdAt: Date?
    let updatedAt: Date?
    let system: Bool?

    enum CodingKeys: String, CodingKey {
        case id, body, author, system
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension GitLabNote {
    /// System notes are activity entries ("changed the milestone") rather than user comments.
    var isSystem: Bool { system ?? false }
}
