import Foundation

/// A page of results plus the cursor needed to fetch the next one.
struct Page<Element> {
    let items: [Element]
    let nextPage: Int?
    var hasMore: Bool { nextPage != nil }
}

/// Thin async wrapper around the GitLab REST API v4.
///
/// All list endpoints return a `Page` so callers can implement infinite scroll
/// using GitLab's keyset/offset pagination headers (`X-Next-Page`).
final class GitLabAPI {
    private let credentials: GitLabCredentials
    private let session: URLSession
    private let decoder: JSONDecoder

    init(credentials: GitLabCredentials, session: URLSession = .shared) {
        self.credentials = credentials
        self.session = session

        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        fallback.formatOptions = [.withInternetDateTime]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = formatter.date(from: string) ?? fallback.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Unrecognised date: \(string)")
        }
        self.decoder = decoder
    }

    var host: URL { credentials.host }

    // MARK: - Request building

    private func makeRequest(path: String,
                             query: [URLQueryItem] = [],
                             method: String = "GET",
                             body: Data? = nil) throws -> URLRequest {
        // Build from a string so callers can pass pre-encoded path segments
        // (e.g. a file path with `%2F`) without `appendingPathComponent`
        // re-encoding the `%`.
        let base = credentials.apiBaseURL.absoluteString
        guard var components = URLComponents(string: base + "/" + path) else {
            throw APIError.invalidURL
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue(credentials.token, forHTTPHeaderField: "PRIVATE-TOKEN")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.server(status: -1, message: nil)
        }
        switch http.statusCode {
        case 200...299:
            return (data, http)
        case 401, 403:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        case 429:
            throw APIError.rateLimited
        default:
            let message = (try? decoder.decode(GitLabErrorBody.self, from: data))?.message
            throw APIError.server(status: http.statusCode, message: message)
        }
    }

    // MARK: - Decoding helpers

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    private func getObject<T: Decodable>(_ type: T.Type,
                                         path: String,
                                         query: [URLQueryItem] = []) async throws -> T {
        let request = try makeRequest(path: path, query: query)
        let (data, _) = try await perform(request)
        return try decode(T.self, from: data)
    }

    private func getPage<T: Decodable>(_ type: T.Type,
                                       path: String,
                                       query: [URLQueryItem] = [],
                                       page: Int = 1,
                                       perPage: Int = 20) async throws -> Page<T> {
        var items = query
        items.append(URLQueryItem(name: "page", value: String(page)))
        items.append(URLQueryItem(name: "per_page", value: String(perPage)))
        let request = try makeRequest(path: path, query: items)
        let (data, http) = try await perform(request)
        let decoded = try decode([T].self, from: data)
        let next = (http.value(forHTTPHeaderField: "X-Next-Page")).flatMap { Int($0) }
        return Page(items: decoded, nextPage: next == 0 ? nil : next)
    }

    // MARK: - Current user

    func currentUser() async throws -> GitLabUser {
        try await getObject(GitLabUser.self, path: "user")
    }

    func user(id: Int) async throws -> GitLabUser {
        try await getObject(GitLabUser.self, path: "users/\(id)")
    }

    // MARK: - Activity feed

    func events(page: Int = 1) async throws -> Page<GitLabEvent> {
        try await getPage(GitLabEvent.self, path: "events", page: page)
    }

    // MARK: - Inbox (to-dos)

    /// The signed-in user's to-do list — GitLab's equivalent of a notification
    /// inbox. Pass `state` ("pending" or "done") to filter.
    func todos(state: String? = nil, page: Int = 1) async throws -> Page<GitLabTodo> {
        var query: [URLQueryItem] = []
        if let state { query.append(URLQueryItem(name: "state", value: state)) }
        return try await getPage(GitLabTodo.self, path: "todos", query: query, page: page)
    }

    // MARK: - Projects

    func myProjects(page: Int = 1, search: String? = nil) async throws -> Page<GitLabProject> {
        var query = [
            URLQueryItem(name: "membership", value: "true"),
            URLQueryItem(name: "order_by", value: "last_activity_at"),
            URLQueryItem(name: "simple", value: "true")
        ]
        if let search, !search.isEmpty { query.append(URLQueryItem(name: "search", value: search)) }
        return try await getPage(GitLabProject.self, path: "projects", query: query, page: page)
    }

    func searchProjects(_ term: String, page: Int = 1) async throws -> Page<GitLabProject> {
        let query = [
            URLQueryItem(name: "search", value: term),
            URLQueryItem(name: "order_by", value: "star_count"),
            URLQueryItem(name: "simple", value: "true")
        ]
        return try await getPage(GitLabProject.self, path: "projects", query: query, page: page)
    }

    func starredProjects(page: Int = 1) async throws -> Page<GitLabProject> {
        let query = [
            URLQueryItem(name: "starred", value: "true"),
            URLQueryItem(name: "order_by", value: "last_activity_at"),
            URLQueryItem(name: "simple", value: "true")
        ]
        return try await getPage(GitLabProject.self, path: "projects", query: query, page: page)
    }

    func project(id: Int) async throws -> GitLabProject {
        try await getObject(GitLabProject.self, path: "projects/\(id)")
    }

    func readme(projectId: Int, ref: String, path: String = "README.md") async throws -> GitLabRepositoryFile {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: allowed) ?? path
        let query = [URLQueryItem(name: "ref", value: ref)]
        return try await getObject(GitLabRepositoryFile.self,
                                   path: "projects/\(projectId)/repository/files/\(encodedPath)",
                                   query: query)
    }

    // MARK: - Issues

    func myIssues(state: String = "opened", scope: String = "assigned_to_me", page: Int = 1) async throws -> Page<GitLabIssue> {
        let query = [
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "order_by", value: "updated_at")
        ]
        return try await getPage(GitLabIssue.self, path: "issues", query: query, page: page)
    }

    func issues(projectId: Int, state: String = "all", page: Int = 1) async throws -> Page<GitLabIssue> {
        let query = [
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "order_by", value: "updated_at")
        ]
        return try await getPage(GitLabIssue.self, path: "projects/\(projectId)/issues", query: query, page: page)
    }

    func issueNotes(projectId: Int, issueIID: Int, page: Int = 1) async throws -> Page<GitLabNote> {
        let query = [URLQueryItem(name: "sort", value: "asc"), URLQueryItem(name: "order_by", value: "created_at")]
        return try await getPage(GitLabNote.self,
                                 path: "projects/\(projectId)/issues/\(issueIID)/notes",
                                 query: query, page: page, perPage: 50)
    }

    // MARK: - Merge requests

    func myMergeRequests(state: String = "opened", scope: String = "assigned_to_me", page: Int = 1) async throws -> Page<GitLabMergeRequest> {
        let query = [
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "order_by", value: "updated_at")
        ]
        return try await getPage(GitLabMergeRequest.self, path: "merge_requests", query: query, page: page)
    }

    func mergeRequests(projectId: Int, state: String = "opened", page: Int = 1) async throws -> Page<GitLabMergeRequest> {
        let query = [
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "order_by", value: "updated_at")
        ]
        return try await getPage(GitLabMergeRequest.self, path: "projects/\(projectId)/merge_requests", query: query, page: page)
    }

    func mergeRequestNotes(projectId: Int, mrIID: Int, page: Int = 1) async throws -> Page<GitLabNote> {
        let query = [URLQueryItem(name: "sort", value: "asc"), URLQueryItem(name: "order_by", value: "created_at")]
        return try await getPage(GitLabNote.self,
                                 path: "projects/\(projectId)/merge_requests/\(mrIID)/notes",
                                 query: query, page: page, perPage: 50)
    }

    // MARK: - CI / CD

    func pipelines(projectId: Int, page: Int = 1) async throws -> Page<GitLabPipeline> {
        let query = [URLQueryItem(name: "order_by", value: "id"), URLQueryItem(name: "sort", value: "desc")]
        return try await getPage(GitLabPipeline.self, path: "projects/\(projectId)/pipelines", query: query, page: page)
    }

    func pipeline(projectId: Int, pipelineId: Int) async throws -> GitLabPipeline {
        try await getObject(GitLabPipeline.self, path: "projects/\(projectId)/pipelines/\(pipelineId)")
    }

    func pipelineJobs(projectId: Int, pipelineId: Int) async throws -> [GitLabJob] {
        try await getObject([GitLabJob].self, path: "projects/\(projectId)/pipelines/\(pipelineId)/jobs")
    }

    /// Jobs across the project's recent pipelines, newest first. Powers the CI dashboard.
    func projectJobs(projectId: Int, page: Int = 1) async throws -> Page<GitLabJob> {
        try await getPage(GitLabJob.self, path: "projects/\(projectId)/jobs", page: page)
    }

    /// Raw trace/log for a single job (plain text).
    func jobLog(projectId: Int, jobId: Int) async throws -> String {
        let request = try makeRequest(path: "projects/\(projectId)/jobs/\(jobId)/trace")
        let (data, _) = try await perform(request)
        return String(data: data, encoding: .utf8) ?? ""
    }

    @discardableResult
    func retryJob(projectId: Int, jobId: Int) async throws -> GitLabJob {
        let request = try makeRequest(path: "projects/\(projectId)/jobs/\(jobId)/retry", method: "POST")
        let (data, _) = try await perform(request)
        return try decode(GitLabJob.self, from: data)
    }

    @discardableResult
    func cancelJob(projectId: Int, jobId: Int) async throws -> GitLabJob {
        let request = try makeRequest(path: "projects/\(projectId)/jobs/\(jobId)/cancel", method: "POST")
        let (data, _) = try await perform(request)
        return try decode(GitLabJob.self, from: data)
    }

    @discardableResult
    func retryPipeline(projectId: Int, pipelineId: Int) async throws -> GitLabPipeline {
        let request = try makeRequest(path: "projects/\(projectId)/pipelines/\(pipelineId)/retry", method: "POST")
        let (data, _) = try await perform(request)
        return try decode(GitLabPipeline.self, from: data)
    }

    // MARK: - Webhooks (used to auto-register push)

    func projectHooks(projectId: Int) async throws -> [GitLabProjectHook] {
        try await getObject([GitLabProjectHook].self, path: "projects/\(projectId)/hooks")
    }

    @discardableResult
    func createProjectHook(projectId: Int, options: WebhookEventOptions) async throws -> GitLabProjectHook {
        let body = try JSONEncoder().encode(options)
        let request = try makeRequest(path: "projects/\(projectId)/hooks", method: "POST", body: body)
        let (data, _) = try await perform(request)
        return try decode(GitLabProjectHook.self, from: data)
    }

    @discardableResult
    func updateProjectHook(projectId: Int, hookId: Int, options: WebhookEventOptions) async throws -> GitLabProjectHook {
        let body = try JSONEncoder().encode(options)
        let request = try makeRequest(path: "projects/\(projectId)/hooks/\(hookId)", method: "PUT", body: body)
        let (data, _) = try await perform(request)
        return try decode(GitLabProjectHook.self, from: data)
    }

    func deleteProjectHook(projectId: Int, hookId: Int) async throws {
        let request = try makeRequest(path: "projects/\(projectId)/hooks/\(hookId)", method: "DELETE")
        _ = try await perform(request)
    }
}

private struct GitLabErrorBody: Decodable {
    let message: String?
    let error: String?

    private enum CodingKeys: String, CodingKey { case message, error }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // `message` can be a string or an object/array; only attempt the string case.
        self.message = (try? container.decode(String.self, forKey: .message))
            ?? (try? container.decode(String.self, forKey: .error))
        self.error = try? container.decode(String.self, forKey: .error)
    }
}
