import Foundation
import Observation

/// Top-level app state: who's signed in, the configured API client, and the
/// auth lifecycle. Injected into the SwiftUI environment.
@Observable
@MainActor
final class AppSession {
    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(GitLabUser)
    }

    private(set) var state: State = .loading
    private(set) var api: GitLabAPI?
    private(set) var credentials: GitLabCredentials?

    /// Set when a sign-in attempt fails, surfaced on the login screen.
    var signInError: String?

    let pushManager = PushNotificationManager()

    init() {}

    /// Called at launch to restore a persisted session.
    func bootstrap() async {
        guard let stored = GitLabCredentials.load() else {
            state = .signedOut
            return
        }
        await configure(with: stored, persist: false)
    }

    /// Validate a host+token, and on success persist + sign in.
    func signIn(host: URL, token: String) async {
        signInError = nil
        let creds = GitLabCredentials(host: host, token: token.trimmingCharacters(in: .whitespacesAndNewlines))
        await configure(with: creds, persist: true)
    }

    private func configure(with creds: GitLabCredentials, persist: Bool) async {
        let client = GitLabAPI(credentials: creds)
        do {
            let user = try await client.currentUser()
            self.credentials = creds
            self.api = client
            if persist { creds.save() }
            self.state = .signedIn(user)
            // Register this device for push once we know who the user is.
            await pushManager.registerIfAuthorized(host: creds.host, user: user)
        } catch let error as APIError {
            // Either the entered token was wrong, or stored creds went stale —
            // both fall back to the login screen.
            signInError = error.errorDescription
            state = .signedOut
        } catch {
            signInError = error.localizedDescription
            state = .signedOut
        }
    }

    func signOut() {
        Task { await pushManager.unregister() }
        GitLabCredentials.clear()
        api = nil
        credentials = nil
        state = .signedOut
    }

    var currentUser: GitLabUser? {
        if case .signedIn(let user) = state { return user }
        return nil
    }
}
