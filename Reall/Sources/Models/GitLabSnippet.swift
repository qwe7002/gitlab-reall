import Foundation

struct GitLabSnippet: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let fileName: String?
    let description: String?
    let visibility: String?
    let author: GitLabUser?
    let webURL: URL?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, description, visibility, author
        case fileName = "file_name"
        case webURL = "web_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
