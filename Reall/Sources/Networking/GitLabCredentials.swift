import Foundation

/// The host + token pair needed to talk to a GitLab instance.
struct GitLabCredentials: Equatable {
    /// Base URL of the instance, e.g. `https://gitlab.com`.
    var host: URL
    /// Personal access token (scopes: `api` or `read_api`).
    var token: String

    var apiBaseURL: URL {
        host.appendingPathComponent("api").appendingPathComponent("v4")
    }
}

extension GitLabCredentials {
    private static let hostKey = "gitlab.host"
    private static let tokenKey = "gitlab.token"

    static let defaultHost = URL(string: "https://gitlab.com")!

    /// Load persisted credentials, if any. The token lives in the Keychain,
    /// the host in UserDefaults (it isn't sensitive).
    static func load() -> GitLabCredentials? {
        guard let token = KeychainStore.get(tokenKey), !token.isEmpty else { return nil }
        let hostString = UserDefaults.standard.string(forKey: hostKey)
        let host = hostString.flatMap(URL.init(string:)) ?? defaultHost
        return GitLabCredentials(host: host, token: token)
    }

    func save() {
        UserDefaults.standard.set(host.absoluteString, forKey: Self.hostKey)
        KeychainStore.set(token, for: Self.tokenKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: hostKey)
        KeychainStore.delete(tokenKey)
    }
}
