import Foundation

/// An activity event for the authenticated user's dashboard feed.
/// https://docs.gitlab.com/ee/api/events.html
struct GitLabEvent: Codable, Identifiable, Hashable {
    let id: Int
    let projectId: Int?
    let actionName: String
    let targetType: String?
    let targetTitle: String?
    let targetIID: Int?
    let createdAt: Date?
    let author: GitLabUser?
    let pushData: PushData?
    let note: GitLabNote?

    enum CodingKeys: String, CodingKey {
        case id, note
        case projectId = "project_id"
        case actionName = "action_name"
        case targetType = "target_type"
        case targetTitle = "target_title"
        case targetIID = "target_iid"
        case createdAt = "created_at"
        case author
        case pushData = "push_data"
    }

    struct PushData: Codable, Hashable {
        let action: String?
        let refType: String?
        let ref: String?
        let commitTitle: String?
        let commitCount: Int?

        enum CodingKeys: String, CodingKey {
            case action, ref
            case refType = "ref_type"
            case commitTitle = "commit_title"
            case commitCount = "commit_count"
        }
    }
}

extension GitLabEvent {
    /// A human readable summary line, GitHub-feed style.
    var summary: String {
        let action = actionName.replacingOccurrences(of: "_", with: " ")
        if let push = pushData {
            let ref = push.ref ?? ""
            return "\(action.capitalizedFirst) \(push.refType ?? "ref") \(ref)".trimmingCharacters(in: .whitespaces)
        }
        if let type = targetType {
            return "\(action.capitalizedFirst) \(type.lowercased())"
        }
        return action.capitalizedFirst
    }

    var iconName: String {
        switch actionName {
        case "pushed", "pushed to", "pushed new": return "arrow.up.circle.fill"
        case "opened": return "plus.circle.fill"
        case "closed": return "xmark.circle.fill"
        case "merged", "accepted": return "arrow.triangle.merge"
        case "commented on": return "text.bubble.fill"
        case "joined": return "person.crop.circle.badge.plus"
        case "created": return "folder.badge.plus"
        case "deleted": return "trash.fill"
        default: return "circle.fill"
        }
    }
}

extension String {
    var capitalizedFirst: String {
        guard let first = first else { return self }
        return first.uppercased() + dropFirst()
    }
}
