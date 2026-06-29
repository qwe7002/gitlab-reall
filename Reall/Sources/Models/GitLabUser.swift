import Foundation

/// A GitLab user as returned by the REST API v4.
/// https://docs.gitlab.com/ee/api/users.html
struct GitLabUser: Codable, Identifiable, Hashable {
    let id: Int
    let username: String
    let name: String
    let avatarURL: URL?
    let webURL: URL?

    // Extended fields, only present on the full `/user` or `/users/:id` payloads.
    var state: String?
    var bio: String?
    var location: String?
    var jobTitle: String?
    var organization: String?
    var pronouns: String?
    var publicEmail: String?
    var followers: Int?
    var following: Int?
    var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, username, name, state, bio, location, organization, pronouns, followers, following
        case avatarURL = "avatar_url"
        case webURL = "web_url"
        case jobTitle = "job_title"
        case publicEmail = "public_email"
        case createdAt = "created_at"
    }
}

extension GitLabUser {
    var displayName: String { name.isEmpty ? username : name }
}
