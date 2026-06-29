import Foundation

/// Configuration for the Cloudflare Worker that bridges GitLab webhooks → APNs.
///
/// The Worker URL is set by the user in Settings (it's their own deployment).
/// Once configured, the app registers its APNs device token with the Worker so
/// it can receive CI/pipeline and review notifications without GitLab email.
enum PushConfiguration {
    private static let workerURLKey = "push.workerURL"
    private static let enabledKey = "push.enabled"

    static var workerURL: URL? {
        get {
            UserDefaults.standard.string(forKey: workerURLKey).flatMap(URL.init(string:))
        }
        set {
            UserDefaults.standard.set(newValue?.absoluteString, forKey: workerURLKey)
        }
    }

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var isConfigured: Bool { workerURL != nil }
}
