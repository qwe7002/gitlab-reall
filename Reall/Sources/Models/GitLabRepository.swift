import Foundation

/// A single repository commit.
/// https://docs.gitlab.com/ee/api/commits.html
struct GitLabCommit: Codable, Identifiable, Hashable {
    let id: String
    let shortId: String
    let title: String
    let message: String?
    let authorName: String?
    let authorEmail: String?
    let createdAt: Date?
    let webURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, title, message
        case shortId = "short_id"
        case authorName = "author_name"
        case authorEmail = "author_email"
        case createdAt = "created_at"
        case webURL = "web_url"
    }
}

/// A repository branch.
/// https://docs.gitlab.com/ee/api/branches.html
struct GitLabBranch: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let merged: Bool?
    let protected: Bool?
    let `default`: Bool?
    let commit: GitLabCommit?
}

/// A CI/CD pipeline.
/// https://docs.gitlab.com/ee/api/pipelines.html
struct GitLabPipeline: Codable, Identifiable, Hashable {
    let id: Int
    let iid: Int?
    let status: String         // "success" | "failed" | "running" | "pending" | ...
    let ref: String?
    let sha: String?
    let webURL: URL?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, iid, status, ref, sha
        case webURL = "web_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// A file fetched from the repository (e.g. the README), base64 encoded.
struct GitLabRepositoryFile: Codable {
    let fileName: String
    let filePath: String
    let encoding: String
    let content: String

    enum CodingKeys: String, CodingKey {
        case fileName = "file_name"
        case filePath = "file_path"
        case encoding, content
    }

    var decodedText: String? {
        guard encoding == "base64",
              let data = Data(base64Encoded: content, options: .ignoreUnknownCharacters) else {
            return content
        }
        return String(data: data, encoding: .utf8)
    }
}
