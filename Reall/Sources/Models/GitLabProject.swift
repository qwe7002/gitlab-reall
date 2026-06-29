import Foundation

/// A GitLab project (repository).
/// https://docs.gitlab.com/ee/api/projects.html
struct GitLabProject: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let nameWithNamespace: String
    let path: String
    let pathWithNamespace: String
    let description: String?
    let avatarURL: URL?
    let webURL: URL?
    let starCount: Int
    let forksCount: Int
    let openIssuesCount: Int?
    let visibility: String?
    let defaultBranch: String?
    let lastActivityAt: Date?
    let archived: Bool?
    let namespace: GitLabNamespace?
    let topics: [String]?

    enum CodingKeys: String, CodingKey {
        case id, name, path, description, visibility, namespace, topics, archived
        case nameWithNamespace = "name_with_namespace"
        case pathWithNamespace = "path_with_namespace"
        case avatarURL = "avatar_url"
        case webURL = "web_url"
        case starCount = "star_count"
        case forksCount = "forks_count"
        case openIssuesCount = "open_issues_count"
        case defaultBranch = "default_branch"
        case lastActivityAt = "last_activity_at"
    }
}

struct GitLabNamespace: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let path: String
    let kind: String?
    let fullPath: String?
    let avatarURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, name, path, kind
        case fullPath = "full_path"
        case avatarURL = "avatar_url"
    }
}
