import Foundation

/// Automates GitLab webhook setup so push "just works" — the app installs the
/// webhook (pointing at the user's Cloudflare Worker) on their projects using
/// the GitLab API, instead of the user adding it by hand.
struct WebhookService {
    let api: GitLabAPI
    /// The Worker's webhook endpoint, e.g. `https://reall-push.../webhook`.
    let webhookURL: String
    /// Per-user secret issued by the Worker; sent as the hook's token.
    let secret: String

    struct InstallSummary {
        var installed = 0
        var skippedNoPermission = 0
        var failed = 0
        var total = 0
    }

    private func options() -> WebhookEventOptions {
        WebhookEventOptions(url: webhookURL, token: secret)
    }

    private func matches(_ hook: GitLabProjectHook) -> Bool {
        normalize(hook.url) == normalize(webhookURL)
    }

    private func normalize(_ string: String) -> String {
        string.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
    }

    /// Whether our webhook is already installed on a project.
    func isInstalled(projectId: Int) async -> Bool {
        guard let hooks = try? await api.projectHooks(projectId: projectId) else { return false }
        return hooks.contains(where: matches)
    }

    /// Create our hook, or update it if one already points at the Worker. Idempotent.
    func ensureHook(projectId: Int) async throws {
        let hooks = (try? await api.projectHooks(projectId: projectId)) ?? []
        if let existing = hooks.first(where: matches) {
            try await api.updateProjectHook(projectId: projectId, hookId: existing.id, options: options())
        } else {
            try await api.createProjectHook(projectId: projectId, options: options())
        }
    }

    /// Remove our hook from a project, if present.
    func removeHook(projectId: Int) async throws {
        let hooks = (try? await api.projectHooks(projectId: projectId)) ?? []
        for hook in hooks where matches(hook) {
            try await api.deleteProjectHook(projectId: projectId, hookId: hook.id)
        }
    }

    /// Install the webhook on every project the user can manage. Projects where
    /// the user lacks maintainer rights (HTTP 403) are counted as skipped.
    func installOnAllProjects(maxPages: Int = 10) async -> InstallSummary {
        var summary = InstallSummary()
        var page = 1
        while page <= maxPages {
            guard let result = try? await api.myProjects(page: page) else { break }
            for project in result.items {
                summary.total += 1
                do {
                    try await ensureHook(projectId: project.id)
                    summary.installed += 1
                } catch let error as APIError where isPermission(error) {
                    summary.skippedNoPermission += 1
                } catch {
                    summary.failed += 1
                }
            }
            guard let next = result.nextPage else { break }
            page = next
        }
        return summary
    }

    private func isPermission(_ error: APIError) -> Bool {
        switch error {
        case .unauthorized, .notFound: return true
        case .server(let status, _): return status == 403
        default: return false
        }
    }
}
