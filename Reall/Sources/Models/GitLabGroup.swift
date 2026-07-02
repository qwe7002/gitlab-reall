import Foundation

struct GitLabGroup: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let path: String
    let fullPath: String?
    let description: String?
    let visibility: String?
    let avatarURL: URL?
    let webURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, name, path, description, visibility
        case fullPath = "full_path"
        case avatarURL = "avatar_url"
        case webURL = "web_url"
    }
}
