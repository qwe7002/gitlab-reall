import Foundation

/// A GitLab to-do item — GitLab's equivalent of a GitHub inbox notification.
/// https://docs.gitlab.com/ee/api/todos.html
struct GitLabTodo: Decodable, Identifiable, Hashable {
    let id: Int
    let actionName: String
    let targetType: String?
    let targetURL: URL?
    let body: String?
    let state: String?          // "pending" | "done"
    let createdAt: Date?
    let author: GitLabUser?
    let project: TodoProject?

    /// The target decoded into a concrete type when we recognise it, so a row
    /// can deep-link into the existing issue / merge request detail screens.
    let issue: GitLabIssue?
    let mergeRequest: GitLabMergeRequest?

    /// The trimmed-down project the todos endpoint embeds (no star/fork counts,
    /// so the full `GitLabProject` model can't decode it).
    struct TodoProject: Decodable, Hashable {
        let id: Int
        let name: String?
        let nameWithNamespace: String?
        let pathWithNamespace: String?

        enum CodingKeys: String, CodingKey {
            case id, name
            case nameWithNamespace = "name_with_namespace"
            case pathWithNamespace = "path_with_namespace"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, body, state, author, project, target
        case actionName = "action_name"
        case targetType = "target_type"
        case targetURL = "target_url"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        actionName = try c.decodeIfPresent(String.self, forKey: .actionName) ?? ""
        targetType = try c.decodeIfPresent(String.self, forKey: .targetType)
        targetURL = try c.decodeIfPresent(URL.self, forKey: .targetURL)
        body = try c.decodeIfPresent(String.self, forKey: .body)
        state = try c.decodeIfPresent(String.self, forKey: .state)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt)
        author = try c.decodeIfPresent(GitLabUser.self, forKey: .author)
        project = try c.decodeIfPresent(TodoProject.self, forKey: .project)

        // Decode the target defensively: a schema we don't expect shouldn't drop
        // the whole row, it just loses the deep link.
        switch targetType {
        case "Issue":
            issue = try? c.decodeIfPresent(GitLabIssue.self, forKey: .target)
            mergeRequest = nil
        case "MergeRequest":
            mergeRequest = try? c.decodeIfPresent(GitLabMergeRequest.self, forKey: .target)
            issue = nil
        default:
            issue = nil
            mergeRequest = nil
        }
    }
}

extension GitLabTodo {
    /// `pending` todos are the unread ones in the inbox.
    var isUnread: Bool { state == "pending" }

    /// e.g. "qwe7002/servercase #9"
    var reference: String {
        let path = project?.pathWithNamespace ?? project?.name ?? ""
        if let iid = issue?.iid ?? mergeRequest?.iid {
            return path.isEmpty ? "#\(iid)" : "\(path) #\(iid)"
        }
        return path
    }

    /// The title of the underlying issue / merge request.
    var title: String? { issue?.title ?? mergeRequest?.title }

    /// A short secondary line describing what happened, GitHub-inbox style.
    var summary: String {
        if let body, !body.isEmpty { return body }
        let action = actionName.replacingOccurrences(of: "_", with: " ")
        return action.capitalizedFirst
    }

    /// Branch-style icon and colour matching the target's kind and state.
    var iconName: String {
        if mergeRequest != nil { return "arrow.triangle.pull" }
        if let issue { return issue.isOpen ? "smallcircle.filled.circle" : "checkmark.circle.fill" }
        return "bell.fill"
    }

    /// Where tapping the row should navigate.
    var route: Route? {
        if let issue { return .issue(issue) }
        if let mergeRequest { return .mergeRequest(mergeRequest) }
        return nil
    }
}
