import Foundation

/// A single CI/CD job within a pipeline.
/// https://docs.gitlab.com/ee/api/jobs.html
struct GitLabJob: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let stage: String?
    let status: String          // "success" | "failed" | "running" | "pending" | "manual" | "canceled" | "skipped"
    let ref: String?
    let allowFailure: Bool?
    let createdAt: Date?
    let startedAt: Date?
    let finishedAt: Date?
    let duration: Double?
    let webURL: URL?
    let user: GitLabUser?
    let pipeline: GitLabPipeline?

    enum CodingKeys: String, CodingKey {
        case id, name, stage, status, ref, duration, user, pipeline
        case allowFailure = "allow_failure"
        case createdAt = "created_at"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case webURL = "web_url"
    }
}

/// Shared semantics for any CI status string (jobs and pipelines).
enum CIStatus: String {
    case created, pending, running, success, failed, canceled, skipped, manual, scheduled, waitingForResource = "waiting_for_resource"
    case preparing
    case unknown

    init(_ raw: String?) {
        self = raw.flatMap(CIStatus.init(rawValue:)) ?? .unknown
    }

    var symbolName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .failed: return "xmark.octagon.fill"
        case .running: return "circle.dotted"
        case .pending, .preparing, .created, .waitingForResource, .scheduled: return "clock.fill"
        case .canceled: return "minus.circle.fill"
        case .skipped: return "arrow.forward.circle.fill"
        case .manual: return "hand.tap.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .waitingForResource: return "Waiting"
        default: return rawValue.capitalizedFirst
        }
    }

    /// Whether the status represents work still in flight (used to drive polling).
    var isActive: Bool {
        switch self {
        case .created, .pending, .preparing, .running, .scheduled, .waitingForResource, .manual:
            return true
        default:
            return false
        }
    }
}
