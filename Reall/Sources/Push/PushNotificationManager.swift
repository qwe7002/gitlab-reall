import Foundation
import Observation
import UIKit
import UserNotifications

/// Coordinates APNs registration and syncing the device token to the
/// Cloudflare Worker so the user receives GitLab CI/review pushes.
@Observable
@MainActor
final class PushNotificationManager {
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var deviceToken: String?
    private(set) var lastError: String?

    /// Cached so we can (re)register with the Worker once the APNs token arrives.
    private var pendingHost: URL?
    private var pendingUser: GitLabUser?

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Ask the user for permission and begin APNs registration.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            return granted
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Register with the Worker if the user has enabled push and granted permission.
    func registerIfAuthorized(host: URL, user: GitLabUser) async {
        pendingHost = host
        pendingUser = user
        await refreshAuthorizationStatus()
        guard PushConfiguration.isEnabled, authorizationStatus == .authorized else { return }
        UIApplication.shared.registerForRemoteNotifications()
        if deviceToken != nil { await syncRegistration() }
    }

    /// Called by the app delegate when APNs hands us a device token.
    func didRegister(deviceToken data: Data) {
        deviceToken = data.map { String(format: "%02x", $0) }.joined()
        Task { await syncRegistration() }
    }

    func didFailToRegister(error: Error) {
        lastError = error.localizedDescription
    }

    /// POST the device token + GitLab identity to the Worker's /register endpoint.
    private func syncRegistration() async {
        guard PushConfiguration.isEnabled,
              let workerURL = PushConfiguration.workerURL,
              let token = deviceToken,
              let host = pendingHost,
              let user = pendingUser else { return }

        let payload = RegistrationPayload(
            deviceToken: token,
            platform: "ios",
            gitlabHost: host.absoluteString,
            gitlabUserId: user.id,
            gitlabUsername: user.username
        )
        var request = URLRequest(url: workerURL.appendingPathComponent("register"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(payload)
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                lastError = "Worker registration failed (HTTP \(http.statusCode))."
            } else {
                lastError = nil
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Tell the Worker to forget this device (on sign-out / disable).
    func unregister() async {
        guard let workerURL = PushConfiguration.workerURL, let token = deviceToken else { return }
        var request = URLRequest(url: workerURL.appendingPathComponent("unregister"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["deviceToken": token])
        _ = try? await URLSession.shared.data(for: request)
    }

    private struct RegistrationPayload: Encodable {
        let deviceToken: String
        let platform: String
        let gitlabHost: String
        let gitlabUserId: Int
        let gitlabUsername: String
    }
}
