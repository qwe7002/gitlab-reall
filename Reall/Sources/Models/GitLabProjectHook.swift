import Foundation

/// A project webhook.
/// https://docs.gitlab.com/ee/api/project_webhooks.html
struct GitLabProjectHook: Codable, Identifiable, Hashable {
    let id: Int
    let url: String
    let pushEvents: Bool?
    let issuesEvents: Bool?
    let mergeRequestsEvents: Bool?
    let pipelineEvents: Bool?
    let jobEvents: Bool?
    let noteEvents: Bool?
    let enableSSLVerification: Bool?

    enum CodingKeys: String, CodingKey {
        case id, url
        case pushEvents = "push_events"
        case issuesEvents = "issues_events"
        case mergeRequestsEvents = "merge_requests_events"
        case pipelineEvents = "pipeline_events"
        case jobEvents = "job_events"
        case noteEvents = "note_events"
        case enableSSLVerification = "enable_ssl_verification"
    }
}

/// The set of events Reall subscribes a webhook to.
struct WebhookEventOptions: Encodable {
    var url: String
    var token: String
    var pipelineEvents = true
    var jobEvents = true
    var mergeRequestsEvents = true
    var noteEvents = true
    var issuesEvents = true
    var pushEvents = false
    var enableSSLVerification = true

    enum CodingKeys: String, CodingKey {
        case url, token
        case pipelineEvents = "pipeline_events"
        case jobEvents = "job_events"
        case mergeRequestsEvents = "merge_requests_events"
        case noteEvents = "note_events"
        case issuesEvents = "issues_events"
        case pushEvents = "push_events"
        case enableSSLVerification = "enable_ssl_verification"
    }
}
